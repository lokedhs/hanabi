defmodule Hanabi.Supervisor do
  use Supervisor

  @moduledoc false
  @name Hanabi.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(_) do
    children = [
      worker(Hanabi.Listener, [], [restart: :permanent]),
      supervisor(Hanabi.SessionSupervisor, [], [restart: :permanent]),
      #supervisor(Hanabi.ChannelSupervisor, [], [restart: :permanent]),
    ]

    supervise(children, strategy: :one_for_one)
  end

  def stop do
    Supervisor.stop(@name)
  end
end
