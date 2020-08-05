defmodule Conditioner do
  @moduledoc """
  A mechanism for smoothing out function calls over seconds, so that no more than a given number
  will happen per second. Should support at least thousands of calls per service.

  It essentially works as a queue where the GenServer call timeout is the load shedding mechanism.
  Since it blocks the caller it doesn't require an inverted flow of adding to queue and workers
  reading from queue. Could also be described as a semaphore where we wait until we can acquire it.
  """

  alias Conditioner.Telemetry
  alias Conditioner.Timeouts

  @doc """
  Given a name, timeout and a configured limit of requests per second, either returns :ok immediately
  or blocks until either it can return :ok or it times out, in which case it returns an error tuple.

  Used to smooth out function calls to the given limit per second. As an example, with a limit of 3
  it will return :ok a maximum of 3 times per second. If called more than 3 times per second,
  subsequent requests will wait until the next second and then the next, until they get an :ok
  or time out.

  If called with a name that hasn't been registered returns `{:error, unknown_name}`.
  """
  def ask(name) do
    case Timeouts.get(name) do
      {:error, :not_found} ->
        Telemetry.execute(
          [:ask, :unknown_name],
          %{name: name}
        )

        {:error, :unknown_name}

      {:ok, limit} ->
        try do
          Telemetry.execute(
            [:ask, :start],
            %{name: name}
          )

          start = timestamp()

          true = GenServer.call(server_name(name), :ask, limit)

          Telemetry.execute([:ask, :end], %{name: name}, %{duration: timestamp() - start})

          :ok
        catch
          :exit, {:timeout, _} ->
            Telemetry.execute(
              [:ask, :timeout],
              %{name: name}
            )

            {:error, :timeout}

          :exit, {:noproc, _} ->
            Telemetry.execute(
              [:ask, :unknown_name],
              %{name: name}
            )

            {:error, :unknown_name}

          reason, message ->
            Telemetry.execute(
              [:ask, :error],
              %{name: name, error: {reason, message}}
            )

            {:error, {reason, message}}
        end
    end
  end

  @doc """
  Registers a name (eg a service) by starting a process to manage it. Only registered names can be used.
  """
  def install(name, opts) do
    opts = Keyword.put(opts, :name, name)
    DynamicSupervisor.start_child(ConditionerSupervisor, {Conditioner.Shard, opts})
  end

  @doc """
  Unregisters a name and stops the corresponding process.
  """
  def uninstall(name) do
    DynamicSupervisor.terminate_child(
      ConditionerSupervisor,
      Process.whereis(server_name(name))
    )
  end

  defp server_name(name), do: :"Conditioner-#{name}"

  defp timestamp(), do: :erlang.monotonic_time(:millisecond)
end
