# Conditioner

**WARNING**: use this at your own risk, it's a work in progress

A mechanism for smoothing out function calls over seconds, so that no more than a given number
will happen per second. Should support at least thousands of calls per service per second.

It essentially works as a queue where the `GenServer.call/2` timeout is the load shedding mechanism.
Since it blocks the caller it doesn't require an inverted flow of adding to queue and workers
reading from queue. Could also be described as a semaphore where we wait until we can acquire it.

## Installation

```elixir
def deps do
  [
    {:conditioner, "~> 0.1.0"}
  ]
end
```

# Usage

Choose a store implementation by setting config. The possible options are `Conditioner.Store.Local` (ETS) and `Conditioner.Store.Redis` (requires a Redis instance).

```elixir
config :conditioner,
  store_impl: Conditioner.Store.Local
```

Call `Conditioner.install/2` for every service you want to manage. Assuming you have 3 services:

```elixir
services ["service 1", "service 2", "service 3"]

for service <- services do
  Conditioner.install(service, limit: 1)
end
```

Now that your conditioner instances are set up you can start using them.

```elixir
case Conditioner.ask("service 1") do
  :ok -> call_service_1(),
  {:error, :timeout} -> # handle your timeout
end
```
