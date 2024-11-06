defmodule LiveBeats.Wallet.Connector do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      :wallet_type,    # :metamask, :wallet_connect, :polkadot_js
      :address,
      :chain_id,
      :connected_at,
      :last_signature
    ]
  end

  # Supported wallet types for Manjaro
  @wallet_options %{
    browser_wallets: [
      {:rabby, "Multi-chain with better security"},
      {:metamask, "Browser extension for ETH chains"},
      {:wallet_connect, "Multi-chain QR connection"}
    ],
    native_wallets: [
      {:mycrypto, "Desktop ETH wallet"},
      {:exodus, "Multi-chain desktop wallet"},
      {:atomic, "Linux-native multi-chain wallet"}
    ]
  }

  def get_wallet_options, do: @wallet_options

  def connect_rabby do
    # Rabby uses the same provider interface as MetaMask
    case detect_ethereum_provider() do
      {:ok, provider} when provider.is_rabby ->
        {:ok, %{
          type: :rabby,
          address: provider.selected_address,
          chain_id: provider.chain_id
        }}
      _ ->
        {:error, "Rabby wallet not found"}
    end
  end
end
