defmodule TimeTracker.StreamBank.Sync do
  @moduledoc """
  Handles blockchain synchronization for the StreamBank.
  Batches local transfers and syncs them to the blockchain efficiently.
  """

  alias TimeTracker.Blockchain.{Config, Transaction, Client}
  require Logger

  @retry_attempts 3
  @retry_base_delay 1000 # 1 second

  @stream_token_abi [
    %{
      "constant": false,
      "inputs": [
        {"name": "recipients", "type": "address[]"},
        {"name": "amounts", "type": "uint256[]"}
      ],
      "name": "batchTransfer",
      "outputs": [{"name": "", "type": "bool"}],
      "type": "function"
    },
    %{
      "constant": true,
      "inputs": [{"name": "account", "type": "address"}],
      "name": "balanceOf",
      "outputs": [{"name": "", "type": "uint256"}],
      "type": "function"
    }
  ]

  @doc """
  Syncs pending transfers to the blockchain in batches.
  Includes retry mechanism and proper error handling.
  """
  def sync_pending_transfers(pending_transfers) when map_size(pending_transfers) > 0 do
    with {:ok, token_address} <- get_token_address(),
         {:ok, batch} <- prepare_batch(pending_transfers) do
      
      do_with_retry(fn ->
        case Client.send_contract_tx(
          token_address,
          "batchTransfer",
          [batch.recipients, batch.amounts]
        ) do
          {:ok, tx_hash} = success ->
            Logger.info("🔄 Synced #{length(batch.recipients)} transfers to blockchain: #{tx_hash}")
            success
          {:error, reason} = error ->
            Logger.error("❌ Failed to sync transfers: #{inspect(reason)}")
            error
        end
      end)
    end
  end

  def sync_pending_transfers(_), do: {:ok, :nothing_to_sync}

  @doc """
  Gets the current on-chain balance for an address.
  Includes retry mechanism for RPC failures.
  """
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

  defp prepare_batch(pending_transfers) do
    {recipients, amounts} = pending_transfers
    |> Enum.map(fn {address, amount} -> {address, abs(amount)} end)
    |> Enum.unzip()

    {:ok, %{recipients: recipients, amounts: amounts}}
  end

  defp get_token_address do
    case System.get_env("STREAM_TOKEN_ADDRESS") do
      nil -> {:error, "STREAM_TOKEN_ADDRESS not set"}
      address -> {:ok, address}
    end
  end
end
