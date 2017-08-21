defmodule Hanabi.IRC do
  alias Hanabi.User
  alias Hanabi.IRC.Message
  require Logger
  use Hanabi.IRC.Numeric

  def parse(data) do
    line = String.trim(data)
    regex = ~r/^(?:[:](\S+) )?(\S+)\s?(.*)$/ui

    if String.match?(line, regex) do
      [_, prefix, command, params] = Regex.run(regex, line)
      {middle, trailing} = parse(:params, params)

      %Message{prefix: prefix, command: command, middle: middle, trailing: trailing}
    else
      %Message{}
    end
  end

  def parse(_, params_string, middle_params \\ nil)
  def parse(:params, "", middle_params), do: {middle_params, nil}
  def parse(:params, params_string, middle_params) do
    [head|tail] = String.split params_string, " ", parts: 2

    if String.starts_with?(head, ":") do
      # 'trailing' parameter
      trailing = unless tail == []do
        String.trim_leading(head, ":") <> " " <> List.to_string(tail)
      else
        String.trim_leading(head, ":")
      end
      {middle_params, trailing}
    else
      # 'middle' parameter
      middle = if middle_params, do: middle_params <> " " <> head, else: head
      parse(:params, List.to_string(tail), middle)
    end
  end

  def resolve_hostname(client) do
    {:ok, {ip, _port}} = :inet.peername(client)
    case :inet.gethostbyaddr(ip) do
      { :ok, { :hostent, hostname, _, _, _, _}} ->
        hostname
      { :error, _error } ->
        Logger.debug "Could not resolve hostname for #{ip}. Using IP instead."
        Enum.join(Tuple.to_list(ip), ".")
    end
  end

  def build(%Message{}=msg) do
    prefix = if msg.prefix, do: ":#{msg.prefix} ", else: ""
    command = msg.command
    {middle, trailing } = case {msg.middle, msg.trailing} do
      {nil, nil} -> {"", ""}
      {mid, nil} -> {" #{mid}", ""}
      {nil, trail} -> {"", " :#{trail}"}
      {mid, trail} -> {" #{mid}", " :#{trail}"}
    end

    prefix <> command <> middle <> trailing
  end

  def send(port, %Message{}=msg) do
    :gen_tcp.send port, build(msg) <> "\r\n"
  end

  ## IRC helpers

  def validate(:nick, nick) do
    regex = ~r/\A[a-z_\-\[\]\\^{}|`][a-z0-9_\-\[\]\\^{}|`]{2,15}\z/ui

    cond do
      !String.match?(nick, regex) -> @err_erroneusnickname
      User.is_in_use?(:nick, nick) -> @err_nicknameinuse
      true -> :ok
    end
  end

  def validate(:channel, name) do
    regex = ~r/#\w+/ui

    if String.match?(name, regex) do
      :ok
    else
      :err
    end
  end

  def validate(:user, %User{}=user) do
    user.key && user.nick && user.username && user.realname && user.hostname
  end
end
