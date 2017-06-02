defmodule Hanabi.Registry do
  use GenServer

  def create(name) do
    table = :ets.new(name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, table}
  end

  def set(name, key, value) do
    :ets.insert(name, {key, value})
  end

  def get(name, key) do
    case :ets.lookup(name, key) do
      [{key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  def dump(name) do
    :ets.match(name, :"$1")
  end

  def drop(name, key) do
    :ets.delete(name, key)
  end
end
