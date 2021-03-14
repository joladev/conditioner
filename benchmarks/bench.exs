Conditioner.install("bench", limit: 1000, window: 200, timeout: 3000)

b = :erlang.monotonic_time(:milli_seconds)

{:ok, agent} = Agent.start_link(fn -> b end)

defmodule Log do
  use GenServer

  def init(_) do
    events = [
      [:conditioner, :ask, :start],
      [:conditioner, :ask, :end],
      [:conditioner, :ask, :timeout],
      [:conditioner, :ask, :unknown_name],
      [:conditioner, :clean],
      [:conditioner, :drop],
      [:conditioner, :count]
    ]

    for event <- events do
      :telemetry.attach(
        "#{inspect(event)}",
        event,
        &__MODULE__.handle_event/4,
        %{}
      )
    end

    {:ok, :ok}
  end

  def handle_event(event, measurements, meta, config) do
    IO.inspect("event: #{inspect(event)}, measurements: #{inspect(measurements)}, meta: #{inspect(meta)}")
  end
end

GenServer.start_link(Log, [], [])

results = Enum.flat_map(1..5, fn _ ->
  tasks = 1..5000
  |> Enum.map(fn _ -> Task.async(fn -> Conditioner.ask("bench") end) end)
  |> (fn tasks ->
    a = :erlang.monotonic_time(:milli_seconds)

    b = Agent.get(agent, fn s -> s end)
    Agent.update(agent, fn _ -> a end)

    IO.inspect("started all tasks: #{(a - b)} ms")

    tasks
  end).()

  Process.sleep(1000)

  tasks
end)

results = Enum.map(results, fn t -> Task.await(t, 10_000) end)

counts = Enum.reduce(results, %{
  ok: 0,
  error: 0,
  timeout: 0
}, fn t, acc ->
  case t do
    :ok -> Map.update!(acc, :ok, & &1 + 1)
    {:error, :timeout} -> Map.update!(acc, :timeout, & &1 + 1)
    {:error, reason} ->
      IO.inspect(reason)
      Map.update!(acc, :unknown, & &1 + 1)
  end
end)

b = Agent.get(agent, fn s -> s end)
a = :erlang.monotonic_time(:milli_seconds)

IO.inspect("took #{(a - b)} ms")

IO.inspect(counts)
