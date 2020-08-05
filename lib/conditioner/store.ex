defmodule Conditioner.Store do
  @callback init() :: term
  @callback incr(name :: binary()) :: integer()
  @callback clear(name :: binary()) :: atom()

  def init(), do: impl().init()

  def incr(name), do: impl().incr(name)
  def clear(name), do: impl().clear(name)

  def impl(), do: Application.fetch_env!(:conditioner, :store_impl)
end
