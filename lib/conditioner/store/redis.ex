defmodule Conditioner.Store.Redis do
  @behaviour Conditioner.Store

  @name ConditionerRedix

  @impl true
  def init() do
    {Redix, name: @name}
  end

  @impl true
  def incr(name) do
    case Redix.command(@name, ["INCR", name]) do
      {:ok, value} -> value
      {:error, error} -> raise "Couldn't incr from Redis: #{inspect(error)}"
    end
  end

  @impl true
  def clear(name) do
    case Redix.command(@name, ["DEL", name]) do
      {:ok, _} -> :ok
      {:error, error} -> raise "Couldn't clear from Redis: #{inspect(error)}"
    end
  end
end
