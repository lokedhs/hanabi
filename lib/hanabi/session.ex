defmodule Hanabi.Session do
  use GenServer

  require Logger

  @greeting "Welcome aboard ! \n"

  def start_link(client) do
     GenServer.start_link(__MODULE__, {:ok, client} , [])
  end

  def init({:ok, client}) do
     Logger.debug "Opening new session."
     send self(), :greet

     {:ok, client}
  end

  def handle_info(:greet, client) do
    :gen_tcp.send(client, @greeting)
    send self(), :listen
    {:noreply, client}
  end

  def handle_info(:listen, client) do
    {:ok, data} = :gen_tcp.recv(client, 0)
    IO.inspect data

    send self(), :listen
    {:noreply, client}
  end
end
