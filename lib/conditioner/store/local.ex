defmodule Conditioner.Store.Local do
  @behaviour Conditioner.Store

  @impl true
  def init() do
    :ets.new(Conditioner.Store.Local, [:public, {:write_concurrency, true}, :named_table])

    nil
  end

  @impl true
  def incr(name), do: :ets.update_counter(__MODULE__, name, {2, 1}, {name, 0})

  @impl true
  def clear(name) do
    true = :ets.delete(__MODULE__, name)
    :ok
  end
end
