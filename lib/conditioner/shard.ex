defmodule Conditioner.Shard do
  use GenServer

  alias Conditioner.Store
  alias Conditioner.Telemetry
  alias Conditioner.Timeout
  alias Conditioner.PriorityQueue

  @state_keys [:queue, :name, :limit, :timeout, :window]

  @enforce_keys @state_keys
  defstruct @state_keys

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: :"Conditioner-#{name}")
  end

  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    limit = Keyword.get(opts, :limit, 5)
    timeout = Keyword.get(opts, :timeout, 5_000)
    window = Keyword.get(opts, :window, 1_000)

    Timeout.put(name, timeout)

    queue = PriorityQueue.new()

    state = %__MODULE__{
      queue: queue,
      name: name,
      limit: limit,
      timeout: timeout,
      window: window
    }

    state = clean(state)

    {:ok, state}
  end

  def handle_info(:clean, state) do
    state = clean(state)

    {:noreply, state}
  end

  def handle_call(
        {:ask, priority},
        from,
        %__MODULE__{queue: queue} = state
      ) do
    queue = PriorityQueue.insert(queue, priority, {from, timestamp()})
    state = flush(%{state | queue: queue})

    {:noreply, state}
  end

  defp clean(%{name: name, window: window, queue: queue} = state) do
    # This is a new window, we can clean the counter.
    Store.clear(name)
    Telemetry.execute([:clean], %{name: name, queue_length: PriorityQueue.length(queue)})

    # Flush the queue to respond to waiting callers.
    state = flush(state)

    Process.send_after(self(), :clean, window)

    state
  end

  defp timestamp(), do: :erlang.monotonic_time(:millisecond)

  # Repeatedly reads from the queue and has 4 branches
  # 1. We've hit the limit of calls for this window, so we halt.
  # 2. The queue is empty, we halt.
  # 3. The next item in the queue is expired, it's discarded and we continue.
  # 4. The next item is not expired, it is replied to and released and we continue.
  defp flush(%{name: name, limit: limit, timeout: timeout} = state) do
    while(state, fn %{queue: queue} = acc ->
      case PriorityQueue.find_min(queue) do
        {priority, {from, timestamp}} ->
          if timestamp() <= timestamp + timeout do
            count = Store.incr(name)

            Telemetry.execute(
              [:count],
              %{
                name: name,
                limit: limit,
                priority: priority,
                queue_length: PriorityQueue.length(queue)
              },
              %{
                count: count
              }
            )

            cond do
              count > limit ->
                {:halt, acc}

              count == limit ->
                GenServer.reply(from, true)

                {:halt, %{state | queue: PriorityQueue.delete_min(queue)}}

              count < limit ->
                GenServer.reply(from, true)

                {:cont, %{state | queue: PriorityQueue.delete_min(queue)}}
            end
          else
            Telemetry.execute([:drop], %{
              name: name,
              limit: limit,
              priority: priority,
              queue_length: PriorityQueue.length(queue)
            })

            {:cont, %{state | queue: PriorityQueue.delete_min(queue)}}
          end

        nil ->
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
