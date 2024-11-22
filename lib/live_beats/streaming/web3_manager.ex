defmodule LiveBeats.Streaming.Web3Manager do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{
      active_streams: %{},
      token_contract: Application.get_env(:live_beats, :token_contract)
    }}
  end

  def handle_tip(%{from: from, to: to, amount: amount, stream_key: stream_key}) do
    # Move web3 logic here from LiveView
    case send_token_transfer(from, to, amount) do
      {:ok, tx_hash} = result ->
        LiveBeats.Streaming.Stream.handle_tip(stream_key, %{
          from: from,
          amount: amount,
          tx_hash: tx_hash,
          timestamp: DateTime.utc_now()
        })
        result
      error -> error
    end
  end

  def handle_stake(%{address: address, amount: amount, stream_key: stream_key}) do
    case stake_tokens(address, amount) do
      {:ok, tx_hash} ->
        # Update stream stake info
        LiveBeats.Streaming.Stream.update_stake(stream_key, %{
          address: address,
          amount: amount,
          tx_hash: tx_hash,
          timestamp: DateTime.utc_now()
        })
        {:ok, tx_hash}
      error -> error
    end
  end

  defp send_token_transfer(from, to, amount) do
    contract = Application.get_env(:live_beats, :token_contract)
    
    case Web3.Contract.send(contract, "transfer", [to, amount], from: from) do
      {:ok, tx_hash} ->
        Logger.info("Token transfer successful: #{tx_hash}")
        {:ok, tx_hash}
      {:error, reason} = error ->
        Logger.error("Token transfer failed: #{inspect(reason)}")
        error
    end
  end

  defp stake_tokens(address, amount) do
    contract = Application.get_env(:live_beats, :staking_contract)
    
    case Web3.Contract.send(contract, "stake", [amount], from: address) do
      {:ok, tx_hash} ->
        Logger.info("Token stake successful: #{tx_hash}")
        {:ok, tx_hash}
      {:error, reason} = error ->
        Logger.error("Token stake failed: #{inspect(reason)}")
        error
    end
  end

  # Server callbacks for managing web3 state
  @impl true
  def handle_call({:get_stake, stream_key}, _from, state) do
    case LiveBeats.Streaming.Stream.get_stake(stream_key) do
      {:ok, stake} -> {:reply, {:ok, stake}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_cast({:update_stake, stream_key, stake}, state) do
    new_state = update_in(state.active_streams[stream_key], fn stream ->
      Map.update(stream || %{}, :stakes, [stake], &[stake | &1])
    end)
    {:noreply, new_state}
  end
end
