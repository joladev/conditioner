defmodule Conditioner.Shard do
  use GenServer

  alias Conditioner.Store
  alias Conditioner.Telemetry
  alias Conditioner.Timeouts

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: :"Conditioner-#{name}")
  end

  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    limit = Keyword.get(opts, :limit, 5)
    timeout = Keyword.get(opts, :timeout, 5000)

    Timeouts.put(name, timeout)

    state = %{queue: :queue.new(), name: name, limit: limit}
    state = clean(state)

    {:ok, state}
  end

  def handle_info(:clean, state) do
    state = clean(state)

    {:noreply, state}
  end

  def handle_call(:ask, from, %{queue: queue} = state) do
    queue = :queue.in({from, timestamp()}, queue)
    state = flush(%{state | queue: queue})
    {:noreply, state}
  end

  defp clean(%{name: name} = state) do
    # This is a new second, we can clean the counter.
    Store.clear(name)
    Telemetry.execute([:clean], %{name: name})

    # Flush the queue to respond to waiting callers.
    state = flush(state)

    Process.send_after(self(), :clean, 1000)

    state
  end

  defp timestamp(), do: :erlang.monotonic_time(:millisecond)

  # Repeatedly reads from the queue and has 4 branches
  # 1. We've hit the limit of calls for this second, so we halt.
  # 2. The queue is empty, we halt.
  # 3. The next item in the queue is expired, it's discarded and we continue.
  # 4. The next item is not expired, it is replied to and released and we continue.
  defp flush(%{name: name, limit: limit} = state) do
    while(state, fn %{queue: queue} = acc ->
      case :queue.out(queue) do
        {{:value, {from, timestamp}}, queue} ->
          if timestamp() <= timestamp + 3000 do
            count = Store.incr(name)
            Telemetry.execute([:count], %{name: name, limit: limit}, %{count: count})

            cond do
              count > limit ->
                {:halt, acc}

              count == limit ->
                GenServer.reply(from, true)

                {:halt, %{state | queue: queue}}

              count < limit ->
                GenServer.reply(from, true)

                {:cont, %{state | queue: queue}}
            end
          else
            Telemetry.execute([:drop], %{name: name})
            {:cont, %{state | queue: queue}}
          end

        {:empty, _} ->
          {:halt, acc}
      end
    end)
  end

  defp while(state, f) do
    case f.(state) do
      {:cont, state} -> while(state, f)
      {:halt, state} -> state
    end
  end
end
