defmodule IrcClient do
  defmodule State do
    defstruct host: "localhost",
              port: Application.get_env(:hanabi, :port),
              pass: "",
              nick: "lambda",
              user: "lambda",
              name: "Test user",
              client: nil,
              handlers: []
  end

  use ExUnit.Case

  setup do
    {:ok, _pid} = Hanabi.start(nil, nil)
    {:ok, _pid} = ExIrc.App.start(nil, nil)
    :ok
  end

  def init do
    {:ok, client}  = ExIrc.start_link!()
    state = struct(State, client: client)
    ExIrc.Client.add_handler state.client, self()

    state
  end

  def connect(state) do
    ExIrc.Client.connect! state.client, state.host, state.port
    state
  end

  def logon(state) do
    ExIrc.Client.logon state.client, state.pass, state.nick, state.user, state.name
    state
  end

  test "IRC (TCP) connect" do
    init() |> connect()

    result = receive do
      {:connected, _host, _port} -> :ok
      msg ->  msg
    after
      1_000 -> :timeout
    end

    assert result == :ok
  end
end
