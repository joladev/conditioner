defmodule Conditioner do
  @moduledoc """
  A mechanism for smoothing out function calls over time, so that no more than a given number
  will happen per window. Should support at least thousands of calls per service per second.

  It essentially works as a queue where the GenServer call timeout is the back pressure mechanism.
  Since it blocks the caller it doesn't require an inverted flow of adding to queue and workers
  reading from queue.
  """

  alias Conditioner.Telemetry
  alias Conditioner.Timeout

  @doc """
  Given a name, timeout and a configured limit of requests per second, either returns :ok immediately
  or blocks until either it can return :ok or it times out, in which case it returns an error tuple.

  Used to smooth out function calls to the given limit per second. As an example, with a limit of 3
  and a window of 1 second it will return :ok a maximum of 3 times per second. If called more than
  3 times per second, subsequent requests will wait until the next second and then the next, until
  they get an :ok or time out.

  Optionally call it with a priority to ensure some requests are prioritised over others. If there is
  available capacity requests are let through no matter the priority, but when capacity is full
  requests with higher priority are handled first.

  If called with a name that hasn't been registered returns `{:error, unknown_name}`.
  If timed out it returns `{:error, :timeout}`.
  """
  def ask(name, priority \\ 1) when is_number(priority) do
    Telemetry.execute(
      [:ask, :start],
      %{name: name}
    )

    start = timestamp()

    case Timeout.fetch(name) do
      {:error, :not_found} ->
        Telemetry.execute(
          [:ask, :unknown_name],
          %{name: name}
        )

        {:error, :unknown_name}

      {:ok, timeout} ->
        try do
          true = GenServer.call(server_name(name), {:ask, priority}, timeout)

          Telemetry.execute([:ask, :end], %{name: name}, %{duration: timestamp() - start})

          :ok
        catch
          :exit, {:timeout, _} ->
            Telemetry.execute(
              [:ask, :timeout],
              %{name: name}
            )

            Telemetry.execute([:ask, :end], %{name: name}, %{duration: timestamp() - start})

            {:error, :timeout}

          :exit, {:noproc, _} ->
            Telemetry.execute(
              [:ask, :unknown_name],
              %{name: name}
            )

            Telemetry.execute([:ask, :end], %{name: name}, %{duration: timestamp() - start})

            {:error, :unknown_name}

          reason, message ->
            Telemetry.execute(
              [:ask, :error],
              %{name: name, error: {reason, message}}
            )

            Telemetry.execute([:ask, :end], %{name: name}, %{duration: timestamp() - start})

            {:error, {reason, message}}
        end
    end
  end

  @doc """
  Registers a name (eg a service) by starting a process to manage it. Only registered names can be used.
  """
  def install(name, opts) do
    opts = Keyword.put(opts, :name, name)
    distributed? = Keyword.put(opts, :name, name)
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

  @doc """
  Checks if a shard exists for name.
  """
  def exists?(name) do
    not is_nil(Process.whereis(server_name(name)))
  end

  defp server_name(name), do: :"Conditioner-#{name}"

  defp timestamp(), do: :erlang.monotonic_time(:millisecond)
end
