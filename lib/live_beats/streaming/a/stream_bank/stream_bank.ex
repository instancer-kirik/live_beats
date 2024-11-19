defmodule TimeTracker.StreamBank do
  use GenServer
  require Logger
  alias TimeTracker.StreamBank.Sync
  alias TimeTracker.Repo

  @scoop_cooldown :timer.minutes(30)
  @base_scoop_amount 100
  @sync_interval :timer.minutes(60)
  @min_onchain_transfer 1000
  @max_pending_amount 10_000
  @max_retry_attempts 3

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def scoop(user_address) do
    GenServer.call(__MODULE__, {:scoop, user_address})
  end

  def splash(from_address, to_address, amount) do
    GenServer.call(__MODULE__, {:splash, from_address, to_address, amount})
  end

  def pool(address) do
    GenServer.call(__MODULE__, {:pool, address})
  end

  def flow() do
    GenServer.call(__MODULE__, :flow)
  end

  def sync_with_chain(address) do
    GenServer.call(__MODULE__, {:sync_chain, address})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    :ets.new(:stream_bank_balances, [:set, :public, :named_table])
    :ets.new(:stream_bank_locks, [:set, :public, :named_table])
    
    # Recover state from persistence
    state = load_persisted_state()
    schedule_sync()
    {:ok, state}
  end

  @impl true
  def handle_call({:scoop, address}, _from, state) do
    case can_scoop?(address, state) do
      true ->
        {new_state, amount} = do_scoop(address, state)
        persist_state(new_state)
        {:reply, {:ok, amount}, new_state}
      false ->
        cooldown = time_until_next_scoop(address, state)
        {:reply, {:error, {:cooldown, cooldown}}, state}
    end
  end

  @impl true
  def handle_call({:splash, from, to, amount}, _from, state) do
    with :ok <- check_pending_limit(from, amount, state),
         :ok <- acquire_lock(from),
         {:ok, from_balance} <- get_balance(from, state),
         true <- from_balance >= amount,
         new_state <- do_transfer(from, to, amount, state) do
      persist_state(new_state)
      release_lock(from)
      {:reply, {:ok, :local_transfer}, new_state}
    else
      {:error, :pending_limit} ->
        {:reply, {:error, :too_many_pending_transfers}, state}
      {:error, :locked} ->
        {:reply, {:error, :transfer_in_progress}, state}
      false -> 
        release_lock(from)
        {:reply, {:error, :insufficient_balance}, state}
      error -> 
        release_lock(from)
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:pool, address}, _from, state) do
    with {:ok, local_balance} <- get_balance(address, state),
         {:ok, chain_balance} <- Sync.get_chain_balance(address) do
      total_balance = local_balance + chain_balance
      {:reply, {:ok, total_balance}, state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:sync_chain, address}, _from, state) do
    case should_sync_to_chain?(address, state) do
      true ->
        # Get all pending transfers for this address
        pending = Map.take(state.pending_sync, [address])
        case Sync.sync_pending_transfers(pending) do
          {:ok, tx_hash} ->
            new_state = %{state | pending_sync: Map.drop(state.pending_sync, [address])}
            persist_state(new_state)
            {:reply, {:ok, tx_hash}, new_state}
          error ->
            {:reply, error, state}
        end
      false ->
        {:reply, {:ok, :not_needed}, state}
    end
  end

  @impl true
  def handle_info(:sync_blockchain, state) do
    to_sync = get_syncable_transfers(state)
    
    case sync_with_retries(to_sync) do
      {:ok, synced_addresses} ->
        new_state = clear_synced_transfers(state, synced_addresses)
        persist_state(new_state)
        schedule_sync()
        {:noreply, new_state}
      {:error, _reason} ->
        # Log error and retry later
        schedule_sync()
        {:noreply, state}
    end
  end

  # Private Functions

  defp schedule_sync do
    Process.send_after(self(), :sync_blockchain, @sync_interval)
  end

  defp get_balance(address, state) do
    {:ok, Map.get(state.balances, address, 0)}
  end

  defp do_transfer(from, to, amount, state) do
    state
    |> update_in([:balances, from], &((&1 || 0) - amount))
    |> update_in([:balances, to], &((&1 || 0) + amount))
    |> update_in([:pending_sync, from], &((&1 || 0) + amount))
    |> update_in([:pool_stats, :total_splashes], &(&1 + 1))
  end

  defp should_sync_to_chain?(address, state) do
    pending = get_in(state.pending_sync, [address]) || 0
    pending >= @min_onchain_transfer
  end

  defp can_scoop?(address, state) do
    case Map.get(state.last_scoops, address) do
      nil -> true
      last_scoop -> 
        DateTime.diff(DateTime.utc_now(), last_scoop, :second) >= @scoop_cooldown
    end
  end

  defp time_until_next_scoop(address, state) do
    last_scoop = Map.get(state.last_scoops, address, DateTime.utc_now())
    elapsed = DateTime.diff(DateTime.utc_now(), last_scoop, :second)
    max(0, @scoop_cooldown - elapsed)
  end

  defp do_scoop(address, state) do
    amount = @base_scoop_amount
    new_state = state
    |> put_in([:last_scoops, address], DateTime.utc_now())
    |> update_in([:balances, address], &((&1 || 0) + amount))
    |> update_in([:pool_stats, :total_scoops], &(&1 + 1))
    
    {new_state, amount}
  end

  defp check_pending_limit(address, amount, state) do
    pending = get_in(state.pending_sync, [address]) || 0
    if pending + amount <= @max_pending_amount do
      :ok
    else
      {:error, :pending_limit}
    end
  end

  defp acquire_lock(address) do
    case :ets.insert_new(:stream_bank_locks, {address, true}) do
      true -> :ok
      false -> {:error, :locked}
    end
  end

  defp release_lock(address) do
    :ets.delete(:stream_bank_locks, address)
  end

  defp sync_with_retries(transfers, attempt \\ 1) do
    case Sync.sync_pending_transfers(transfers) do
      {:ok, tx_hash} -> {:ok, Map.keys(transfers)}
      {:error, _reason} when attempt < @max_retry_attempts ->
        # Exponential backoff
        :timer.sleep(1000 * :math.pow(2, attempt))
        sync_with_retries(transfers, attempt + 1)
      error -> error
    end
  end

  defp get_syncable_transfers(state) do
    state.pending_sync
    |> Enum.filter(fn {_addr, amount} -> amount >= @min_onchain_transfer end)
    |> Map.new()
  end

  defp clear_synced_transfers(state, synced_addresses) do
    %{state | pending_sync: Map.drop(state.pending_sync, synced_addresses)}
  end

  defp persist_state(state) do
    # TODO: Implement actual persistence (e.g., to database)
    # This is a placeholder for now
    state
  end

  defp load_persisted_state do
    # TODO: Load state from persistence
    %{
      balances: %{},
      last_scoops: %{},
      pending_sync: %{},
      pool_stats: %{
        total_scoops: 0,
        total_splashes: 0,
        current_flow_rate: @base_scoop_amount
      }
    }
  end
end
