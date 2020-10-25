defmodule ConditionerTest do
  use ExUnit.Case
  doctest Conditioner

  setup do
    name = sequence()
    Conditioner.install(name, limit: 1, timeout: 100)

    on_exit(fn ->
      Conditioner.uninstall(name)
      :ok
    end)

    %{name: name}
  end

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

  test "check if a name exists", %{name: name} do
    assert true == Conditioner.exists?(name)
    assert false == Conditioner.exists?("doesn't exist")
  end

  test "ensure happy path telemetry events fire", %{name: name} do
    attach_events(name)

    assert :ok = Conditioner.ask(name)

    assert_received {:event, [:conditioner, :ask, :start], _, %{name: name}, _}
    assert_received {:event, [:conditioner, :ask, :end], %{duration: _}, %{name: name}, _}
    assert_received {:event, [:conditioner, :count], %{count: 1}, %{name: name}, _}
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
    assert_received {:event, [:conditioner, :ask, :timeout], _, %{name: name}, _}
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

  def detach_events(handler_ids) do
    for handler_id <- handler_ids do
      IO.inspect(:telemetry.detach(handler_id))
    end
  end

  def sequence() do
    :erlang.monotonic_time()
    |> Integer.to_string()
    |> (fn s -> :binary.part(s, {byte_size(s), -5}) end).()
  end
end
