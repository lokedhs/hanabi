defmodule Hanabi do
  @moduledoc """
  Documentation for Hanabi.
  """

  def start(_type, _args) do
    Hanabi.Supervisor.start_link
  end
end
