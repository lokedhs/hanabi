defmodule Hanabi.IRC.Message do
  alias Hanabi.IRC.Message
  @moduledoc false

  # See https://tools.ietf.org/html/rfc1459#section-2.3.1
  defstruct prefix: nil,
    command: "nil",
    middle: nil,
    trailing: nil

  def build(prefix, command, middle, trailing) do
    %Message{
      prefix: prefix,
      command: command,
      middle: middle,
      trailing: trailing
    }
  end
end
