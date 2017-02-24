defmodule Hanabi.SessionSupervisor do
  use Supervisor

  @moduledoc false
  @name Hanabi.SessionSupervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end

  def init(_) do
    children = [
      worker(Hanabi.Session, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  def pop(client) do
    IO.inspect Supervisor.start_child(@name, [client])
  end

  def drop(client) do
    Supervisor.terminate_child @name, client
  end
end
