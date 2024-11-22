defmodule LiveBeats.StreamBank.Sync do
  @moduledoc """
  Handles blockchain synchronization for the StreamBank.
  Batches local transfers and syncs them to the blockchain efficiently.
  """

  alias BlockchainCore.{Client, Config}
  require Logger

  @retry_attempts 3
  @retry_base_delay 1000 # 1 second
  @max_batch_size 100 # Maximum number of transfers in a single batch

  @stream_token_abi [
    %{
      "constant" => false,
      "inputs" => [
        %{"name" => "recipients", "type" => "address[]"},
        %{"name" => "amounts", "type" => "uint256[]"}
      ],
      "name" => "batchTransfer",
      "outputs" => [
        %{"name" => "", "type" => "bool"}
      ],
      "payable" => false,
      "stateMutability" => "nonpayable",
      "type" => "function"
    },
    %{
      "constant" => true,
      "inputs" => [
        %{"name" => "account", "type" => "address"}
      ],
      "name" => "balanceOf",
      "outputs" => [
        %{"name" => "", "type" => "uint256"}
      ],
      "payable" => false,
      "stateMutability" => "view",
      "type" => "function"
    }
  ]

  @type transfer :: {eth_address(), token_amount()}
  @type eth_address :: <<_::160>>
  @type token_amount :: non_neg_integer()

  @doc """
  Syncs pending transfers to the blockchain in batches.
  Returns {:ok, tx_hash} on success or {:error, reason} on failure.
  """
  @spec sync_pending_transfers([transfer()]) :: {:ok, String.t()} | {:error, term()}
  def sync_pending_transfers([]), do: {:ok, :nothing_to_sync}
  def sync_pending_transfers(pending_transfers) when length(pending_transfers) > 0 do
    with {:ok, token_address} <- get_token_address(),
         {:ok, batches} <- prepare_batches(pending_transfers),
         {:ok, total_amount} <- validate_total_amount(batches),
         {:ok, _balance} <- validate_sender_balance(total_amount) do
      
      results = Enum.map(batches, fn batch ->
        do_with_retry(fn ->
          case Client.send_contract_tx(
            token_address,
            "batchTransfer",
            [batch.recipients, batch.amounts]
          ) do
            {:ok, tx_hash} = success ->
              case wait_for_confirmation(tx_hash) do
                {:ok, _receipt} ->
                  Logger.info("🔄 Synced #{length(batch.recipients)} transfers to blockchain: #{tx_hash}")
                  success
                error ->
                  Logger.error("❌ Transaction failed: #{inspect(error)}")
                  error
              end
            {:error, reason} = error ->
              Logger.error("❌ Failed to sync transfers: #{inspect(reason)}")
              error
          end
        end)
      end)

      case Enum.find(results, &(elem(&1, 0) == :error)) do
        nil -> {:ok, :synced}
        error -> error
      end
    end
  end

  @doc """
  Gets the current on-chain balance for an address.
  Returns {:ok, balance} on success or {:error, reason} on failure.
  """
  @spec get_chain_balance(eth_address()) :: {:ok, non_neg_integer()} | {:error, term()}
  def get_chain_balance(address) do
    with {:ok, token_address} <- get_token_address() do
      do_with_retry(fn ->
        case Client.call_contract(token_address, "balanceOf", [address]) do
          {:ok, balance} -> {:ok, balance}
          {:error, reason} ->
            Logger.error("Failed to get chain balance: #{inspect(reason)}")
            {:error, reason}
        end
      end)
    end
  end

  # Private Functions

  defp do_with_retry(fun, attempts \\ @retry_attempts) do
    case fun.() do
      {:ok, result} -> {:ok, result}
      {:error, reason} when attempts > 1 ->
        delay = @retry_base_delay * (@retry_attempts - attempts + 1)
        Logger.warning("Operation failed, retrying in #{delay}ms... (#{attempts - 1} attempts left)")
        Process.sleep(delay)
        do_with_retry(fun, attempts - 1)
      error -> error
    end
  end

  defp prepare_batches(pending_transfers) do
    batches = pending_transfers
    |> Enum.chunk_every(@max_batch_size)
    |> Enum.map(fn batch ->
      {recipients, amounts} = batch
      |> Enum.map(fn {address, amount} -> {address, abs(amount)} end)
      |> Enum.unzip()

      %{recipients: recipients, amounts: amounts}
    end)

    {:ok, batches}
  rescue
    error ->
      Logger.error("Failed to prepare batches: #{inspect(error)}")
      {:error, :batch_preparation_failed}
  end

  defp validate_total_amount(batches) do
    total = Enum.reduce(batches, 0, fn batch, acc ->
      acc + Enum.sum(batch.amounts)
    end)
    {:ok, total}
  rescue
    error ->
      Logger.error("Failed to calculate total amount: #{inspect(error)}")
      {:error, :amount_validation_failed}
  end

  defp validate_sender_balance(required_amount) do
    with {:ok, sender} <- get_sender_address(),
         {:ok, balance} <- get_chain_balance(sender) do
      if balance >= required_amount do
        {:ok, balance}
      else
        {:error, :insufficient_balance}
      end
    end
  end

  defp wait_for_confirmation(tx_hash, attempts \\ 50) do
    case Client.get_transaction_receipt(tx_hash) do
      {:ok, receipt} when not is_nil(receipt) ->
        case receipt.status do
          1 -> {:ok, receipt}
          0 -> {:error, :transaction_failed}
        end
      _ when attempts > 0 ->
        Process.sleep(1000)
        wait_for_confirmation(tx_hash, attempts - 1)
      _ -> {:error, :confirmation_timeout}
    end
  end

  defp get_token_address do
    case System.get_env("STREAM_TOKEN_ADDRESS") do
      nil -> {:error, "STREAM_TOKEN_ADDRESS not set"}
      address -> {:ok, address}
    end
  end

  defp get_sender_address do
    case System.get_env("STREAM_SENDER_ADDRESS") do
      nil -> {:error, "STREAM_SENDER_ADDRESS not set"}
      address -> {:ok, address}
    end
  end
end
