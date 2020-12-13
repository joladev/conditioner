defmodule Conditioner.PriorityQueueTest do
  use ExUnit.Case

  alias Conditioner.PriorityQueue, as: PQ

  describe "PriorityQueue" do
    test "should return value for min key" do
      pq = PQ.new() |> PQ.insert(2, :b) |> PQ.insert(3, :c) |> PQ.insert(1, :a)

      assert PQ.find_min(pq) == {1, :a}

      pq = PQ.delete_min(pq)

      assert {{2, :b}, pq} = PQ.pop_min(pq)

      assert PQ.find_min(pq) == {3, :c}
    end
  end
end
