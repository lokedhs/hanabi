defmodule Hanabi do
  import Supervisor.Spec

  @port Application.get_env :hanabi, :port

  def start(_type, _args) do
    Supervisor.start_link(__MODULE__, :ok, [])
  end

  def init(_) do
    children = [
      worker(Task, [Hanabi.Server, :accept, [@port]]),
      #supervisor(Hanabi.SessionSupervisor, [], [restart: :permanent]),
      #supervisor(Hanabi.ChannelSupervisor, [], [restart: :permanent]),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
