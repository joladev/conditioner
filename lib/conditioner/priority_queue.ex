defmodule Conditioner.PriorityQueue do
  @moduledoc false
  # A priority queue implemented in the form of a pairing heap. The value of
  # the key is used to determine the order, based on Erlang term ordering.

  defstruct heap: nil, length: 0

  def new(), do: %__MODULE__{}
  def new(key, value), do: %__MODULE__{heap: {key, value, []}, length: 1}

  def insert(%__MODULE__{heap: heap, length: length} = pq, key, value) do
    heap = meld(heap, {key, value, []})

    %__MODULE__{pq | heap: heap, length: length + 1}
  end

  def find_min(%__MODULE__{length: 0}), do: nil

  def find_min(%__MODULE__{heap: {key, value, _sub_heaps}}), do: {key, value}

  def delete_min(%__MODULE__{length: 0} = pq), do: pq

  def delete_min(%__MODULE__{heap: {_key, _value, sub_heaps}, length: length} = pq) do
    heap = pair(sub_heaps)

    %__MODULE__{pq | heap: heap, length: length - 1}
  end

  def length(%__MODULE__{length: length}), do: length

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
