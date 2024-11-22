defmodule LiveBeatsWeb.Components.WalletConnect do
  use LiveBeatsWeb, :live_component
  import Phoenix.HTML
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  def render(assigns) do
    ~H"""
    <div class="wallet-connect-modal">
      <h3 class="text-lg font-medium">Connect Wallet</h3>

      <div class="wallet-options">
        <div class="browser-wallets">
          <h4>Browser Wallets</h4>
          <button phx-click="connect-metamask" class="wallet-btn">
            MetaMask
          </button>
          <button phx-click="connect-walletconnect" class="wallet-btn">
            WalletConnect
          </button>
        </div>

        <div class="native-wallets">
          <h4>Linux Native Wallets</h4>
          <button phx-click="connect-mycrypto" class="wallet-btn">
            MyCrypto Desktop
          </button>
          <button phx-click="connect-exodus" class="wallet-btn">
            Exodus
          </button>
          <button phx-click="connect-atomic" class="wallet-btn">
            Atomic Wallet
          </button>
        </div>
      </div>
    </div>
    """
  end
end
