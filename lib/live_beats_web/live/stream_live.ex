defmodule LiveBeatsWeb.StreamLive do
  use LiveBeatsWeb, :live_view

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
