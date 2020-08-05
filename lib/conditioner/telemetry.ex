defmodule Conditioner.Telemetry do
  def execute(event, metadata, value \\ %{}) do
    :telemetry.execute(
      [:conditioner] ++ event,
      value,
      metadata
    )
  end
end
