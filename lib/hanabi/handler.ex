defmodule Hanabi.Handler do
  use GenEvent

  def handle_event({ event, parts, client }, messages) do
    { :ok, [{event, parts, client} | messages ]}
  end

  def handle_call(:messages, messages) do
    { :ok, messages, [] }
  end

  def handle_events do
    stream = GenEvent.stream(Events)
    for event <- stream do
      case event do
        _ ->
          IO.puts "Unhandled event!"
          IO.inspect(event)
      end
    end
  end
end
