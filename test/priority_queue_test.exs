defmodule Conditioner.PriorityQueueTest do
  use ExUnit.Case

  alias Conditioner.PriorityQueue, as: PQ

  describe "PriorityQueue" do
    test "should return value for min key" do
      pq = PQ.new() |> PQ.insert(2, :b) |> PQ.insert(3, :c) |> PQ.insert(1, :a)

      assert PQ.length(pq) == 3
      assert PQ.find_min(pq) == {1, :a}

      pq = PQ.delete_min(pq)

      assert PQ.length(pq) == 2
      assert PQ.find_min(pq) == {2, :b}

      pq = PQ.delete_min(pq)

      assert PQ.length(pq) == 1
      assert PQ.find_min(pq) == {3, :c}

      pq = PQ.delete_min(pq)

      assert PQ.length(pq) == 0
      assert PQ.find_min(pq) == nil
    end
  end
end
