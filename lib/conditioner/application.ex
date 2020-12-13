defmodule Conditioner.Application do
  @moduledoc false

  use Application

  alias Conditioner.Timeout

  def start(_type, _args) do
    Timeout.init()

    store_impl = Application.fetch_env!(:conditioner, :store_impl)

    children =
      Enum.reject(
        [
          {DynamicSupervisor, name: ConditionerSupervisor, strategy: :one_for_one},
          store_impl.init()
        ],
        &is_nil/1
      )

    opts = [strategy: :one_for_one, name: Conditioner.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
