defmodule Hanabi.Listener do
  use GenServer

  require Logger

  @moduledoc false
  @port 5674

  def start_link(opts \\ []) do
     GenServer.start_link(__MODULE__, :ok , [opts])
  end

  def init(:ok) do
    {:ok, socket} = :gen_tcp.listen(@port,
                    [:binary, packet: :line, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{@port}"

    send self(), :listen
    {:ok, socket}
  end

  def handle_info(:listen, socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    dispatch(client)

    send self(), :listen
    {:noreply, socket}
  end

  defp dispatch(client) do
    Hanabi.SessionSupervisor.pop(client)
  end
end
