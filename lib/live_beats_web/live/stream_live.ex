defmodule LiveBeatsWeb.StreamLive do
  use LiveBeatsWeb, :live_view

  def format_milestone(milestone) do
    case milestone do
      :bronze -> "Bronze"
      :silver -> "Silver"
      :gold -> "Gold"
      :diamond -> "Diamond"
      _ -> "Unknown"
    end
  end

  def supported_tokens do
    ["BEATS", "ETH"]
  end

  def tip_progress_percentage(tips, goal) do
    total = Enum.reduce(tips, 0, fn tip, acc -> acc + tip.amount end)
    Float.round(total / goal * 100, 1)
  end

  def update_token_balance(socket) do
    case LiveBeats.Streaming.Web3Manager.get_token_balance(socket.assigns.wallet.address) do
      {:ok, balance} -> assign(socket, :token_balance, balance)
      {:error, _} -> socket
    end
  end

  def handle_event("send-tip", %{"amount" => amount}, socket) do
    case LiveBeats.Streaming.Web3Manager.handle_tip(
      from: socket.assigns.wallet.address,
      to: socket.assigns.current_stream.streamer_address,
      amount: amount
    ) do
      {:ok, tx_hash} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tip sent!")
         |> update(:token_balance, &(&1 - String.to_integer(amount)))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send tip: #{reason}")}
    end
  end

  def handle_event("stake-tokens", %{"amount" => amount}, socket) do
    case LiveBeats.Streaming.Web3Manager.handle_stake(
      address: socket.assigns.wallet.address,
      amount: amount
    ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> update_token_balance()
         |> put_flash(:info, "Staked successfully!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Staking failed: #{reason}")}
    end
  end
end
