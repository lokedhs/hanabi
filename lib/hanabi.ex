defmodule Hanabi do
  import Supervisor.Spec

  @moduledoc false
  @port Application.get_env :hanabi, :port

  def start(), do: start(nil, nil)
  def start(_type, _args) do
    Supervisor.start_link(__MODULE__, :ok, [])
  end

  def init(_) do
    children = [
      worker(Task, [Hanabi.Server, :accept, [@port]]),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
