defmodule LiveBeats.Streaming.Config do
  # Option 1: Traditional Centralized (Simplest to start with)
  @stream_mode :centralized

  # Option 2: Hybrid (Balance between control and P2P benefits)
  @stream_mode :hybrid

  # Option 3: Full P2P (Most decentralized but hardest to control)
  @stream_mode :p2p
end
