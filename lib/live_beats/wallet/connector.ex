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

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_wallet_options, do: @wallet_options

  def connect_wallet(type) when type in [:rabby, :metamask, :wallet_connect] do
    GenServer.call(__MODULE__, {:connect_wallet, type})
  end

  def disconnect_wallet do
    GenServer.call(__MODULE__, :disconnect_wallet)
  end

  def get_connection_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def sign_message(message) do
    GenServer.call(__MODULE__, {:sign_message, message})
  end

  # Server Callbacks
  @impl true
  def init(_opts) do
    {:ok, %State{}}
  end

  @impl true
  def handle_call({:connect_wallet, type}, _from, state) do
    case do_connect_wallet(type) do
      {:ok, wallet_info} ->
        new_state = %State{
          wallet_type: type,
          address: wallet_info.address,
          chain_id: wallet_info.chain_id,
          connected_at: DateTime.utc_now()
        }
        {:reply, {:ok, wallet_info}, new_state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:disconnect_wallet, _from, state) do
    case do_disconnect_wallet(state.wallet_type) do
      :ok ->
        {:reply, :ok, %State{}}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      connected: state.address != nil,
      wallet_type: state.wallet_type,
      address: state.address,
      chain_id: state.chain_id,
      connected_at: state.connected_at
    }
    {:reply, status, state}
  end

  @impl true
  def handle_call({:sign_message, message}, _from, state) do
    case do_sign_message(message, state) do
      {:ok, signature} = result ->
        new_state = %{state | last_signature: signature}
        {:reply, result, new_state}
      error ->
        {:reply, error, state}
    end
  end

  # Private Functions
  defp do_connect_wallet(:rabby), do: connect_rabby()
  defp do_connect_wallet(:metamask), do: connect_metamask()
  defp do_connect_wallet(:wallet_connect), do: connect_wallet_connect()

  defp connect_rabby do
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

  defp connect_metamask do
    case detect_ethereum_provider() do
      {:ok, provider} when provider.is_metamask ->
        {:ok, %{
          type: :metamask,
          address: provider.selected_address,
          chain_id: provider.chain_id
        }}
      _ ->
        {:error, "MetaMask not found"}
    end
  end

  defp connect_wallet_connect do
    config = Application.get_env(:live_beats, :wallet_connect) ||
      raise "WalletConnect configuration not found"

    case WalletConnect.Client.connect(config) do
      {:ok, session} ->
        {:ok, %{
          type: :wallet_connect,
          address: session.acts |> List.first(),
          chain_id: session.chain_id
        }}
      error ->
        error
    end
  end

  defp do_disconnect_wallet(:wallet_connect) do
    WalletConnect.Client.disconnect()
  end
  defp do_disconnect_wallet(_), do: :ok

  defp do_sign_message(message, %{wallet_type: :wallet_connect} = state) do
    WalletConnect.Client.personal_sign(message, state.address)
  end

  defp do_sign_message(message, state) do
    case detect_ethereum_provider() do
      {:ok, provider} ->
        provider.request(%{
          method: "personal_sign",
          params: [message, state.address]
        })
      error ->
        error
    end
  end

  defp detect_ethereum_provider do
    try do
      provider_data = File.read!("/tmp/ethereum_provider")
      case :erlang.binary_to_term(provider_data) do
        %{type: type} = provider when type in [:rabby, :metamask] ->
          {:ok, provider}
        _ ->
          {:error, "No compatible Ethereum provider found"}
      end
    rescue
      e ->
        Logger.error("Failed to detect Ethereum provider: #{inspect(e)}")
        {:error, "Failed to detect Ethereum provider"}
    end
  end
end
