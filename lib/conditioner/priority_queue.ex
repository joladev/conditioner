defmodule Conditioner.PriorityQueue do
  @moduledoc false
  # A priority queue implemented in the form of a pairing heap. The value of
  # the key is used to determine the order, based on Erlang term ordering.

  def new(), do: nil
  def new(key, value), do: {key, value, []}

  def pop_min(nil), do: nil
  def pop_min(args), do: {find_min(args), delete_min(args)}

  def insert(heap, key, value) do
    meld(heap, {key, value, []})
  end

  def find_min(nil), do: nil
  def find_min({key, value, _sub_heaps}), do: {key, value}

  def delete_min(nil), do: nil
  def delete_min({_key, _value, sub_heaps}), do: pair(sub_heaps)

  defp pair([]), do: nil
  defp pair([h]), do: h
  defp pair([h1, h2 | hs]) do
    meld(meld(h1, h2), pair(hs))
  end

  defp meld(nil, heap), do: heap
  defp meld(heap, nil), do: heap
  defp meld({l_key, l_value, l_sub_heaps} = l, {r_key, r_value, r_sub_heaps} = r) do
    cond do
      l_key < r_key -> {l_key, l_value, [r | l_sub_heaps]}
      true -> {r_key, r_value, [l | r_sub_heaps]}
    end
  end
end
