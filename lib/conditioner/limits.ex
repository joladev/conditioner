defmodule Conditioner.Timeouts do
  @table :conditioner_timeouts

  def init(), do: :ets.new(@table, [{:read_concurrency, true}, :public, :named_table])

  def put(name, limit), do: :ets.insert(@table, {name, limit})

  def get(name) do
    case :ets.lookup(@table, name) do
      [] -> {:error, :not_found}
      [{_name, limit}] -> {:ok, limit}
    end
  end
end
