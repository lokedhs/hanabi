defmodule Hanabi do
  import Supervisor.Spec

  @moduledoc false
  @port Application.get_env :hanabi, :port

  def start(), do: start(nil, nil)
  def start(_type, _args) do
    Supervisor.start_link(__MODULE__, :ok, [])
  end

  def init(_) do
    # Supervisor
    children = [
      worker(Hanabi.Registry, [:users], [restart: :permanent, id: UserRegistry]),
      worker(Hanabi.Registry, [:channels], [restart: :permanent, id: ChannelRegistry]),
      worker(Task, [Hanabi.Server, :accept, [@port]], restart: :permanent),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
