const MANJARO_WALLET_OPTIONS = {
  // Browser-based options
  browser: {
    metamask: {
      install: "yay -S chromium-extension-metamask",
      pros: ["Most popular", "Large ecosystem", "Easy to use"],
      cons: ["Browser-dependent", "Requires browser restart"]
    },
    walletConnect: {
      install: "Available via QR code - no installation needed",
      pros: ["Works with mobile wallets", "Chain agnostic"],
      cons: ["Requires mobile device"]
    }
  },

  // Native desktop options
  desktop: {
    mycrypto: {
      install: "yay -S mycrypto-bin",
      pros: ["Native app", "Security focused"],
      cons: ["ETH-focused only"]
    },
    exodus: {
      install: "yay -S exodus",
      pros: ["Multi-chain", "Built-in exchange"],
      cons: ["Closed source"]
    },
    atomic: {
      install: "yay -S atomic-wallet",
      pros: ["Linux native", "Multi-chain"],
      cons: ["Heavy resource usage"]
    }
  },

  // Command-line options for advanced users
  cli: {
    ethers_cli: {
      install: "npm install -g ethers-cli",
      pros: ["Lightweight", "Scriptable"],
      cons: ["Command line only"]
    }
  }
} 