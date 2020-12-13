defmodule ConditionerTest do
  use ExUnit.Case

  setup(context) do
    limit = Map.get(context, :limit, 1)
    timeout = Map.get(context, :conditioner_timeout, 100)

    # Generate a unique name for each test run to avoid conflicts.
    name = sequence()
    Conditioner.install(name, limit: limit, timeout: timeout)

    on_exit(fn ->
      Conditioner.uninstall(name)
      :ok
    end)

    %{name: name}
  end

  describe "Conditioner.ask/{1,2}" do
    test "responds with :ok when asked", %{name: name} do
      assert :ok = Conditioner.ask(name)
    end

    test "given too many asks in a timespan", %{name: name} do
      assert :ok = Conditioner.ask(name)
      assert {:error, :timeout} = Conditioner.ask(name)
    end

    test "asks for name that doesn't exist" do
      assert {:error, :unknown_name} = Conditioner.ask("some name")
    end

    @tag conditioner_timeout: 1001
    test "higher priority requests come first", %{name: name} do
      t1 = Task.async(fn -> Conditioner.ask(name, 1) end)
      t2 = Task.async(fn -> Conditioner.ask(name, 2) end)
      t3 = Task.async(fn -> Conditioner.ask(name, 1) end)

      [t1, t2, t3] = Enum.map([t1, t2, t3], &Task.await/1)

      assert t1 == :ok
      assert t2 == {:error, :timeout}
      assert t3 == :ok
    end
  end

  describe "exists?/1" do
    test "check if a name exists", %{name: name} do
      assert true == Conditioner.exists?(name)
      assert false == Conditioner.exists?("doesn't exist")
    end
  end

  describe "telemetry" do
    test "ensure happy path telemetry events fire", %{name: name} do
      attach_events(name)

      assert :ok = Conditioner.ask(name)

      assert_received {:event, [:conditioner, :ask, :start], _, %{name: ^name}, _}
      assert_received {:event, [:conditioner, :ask, :end], %{duration: _}, %{name: ^name}, _}

      assert_received {:event, [:conditioner, :count], %{count: 1},
                       %{name: ^name, limit: 1, priority: 1}, _}
    end

    test "ensure unknown name telemetry event fires", %{name: name} do
      attach_events(name)

      assert {:error, :unknown_name} = Conditioner.ask("wrong name")
      assert_received {:event, [:conditioner, :ask, :unknown_name], _, %{name: "wrong name"}, _}
    end

    test "ensure timeout telemetry events fire", %{name: name} do
      attach_events(name)

      assert :ok = Conditioner.ask(name)
      assert {:error, :timeout} = Conditioner.ask(name)
      assert_received {:event, [:conditioner, :ask, :timeout], _, %{name: ^name}, _}

      # Wait until the next second
      Process.sleep(1001)

      assert_received {:event, [:conditioner, :drop], _, %{name: ^name, limit: 1, priority: 1}, _}
    end
  end

  def handle_event(event, measurements, meta, config) do
    send(config.pid, {:event, event, measurements, meta, config})
  end

  def attach_events(name) do
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
        "#{inspect(event)}-#{name}",
        event,
        &__MODULE__.handle_event/4,
        %{pid: self()}
      )
    end
  end

  def sequence() do
    :erlang.monotonic_time()
    |> Integer.to_string()
    |> (fn s -> :binary.part(s, {byte_size(s), -5}) end).()
  end
end
