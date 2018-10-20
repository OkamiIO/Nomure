defmodule Nomure.Node.ChunkImpl.Property do
  alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Database.State

  @max_string_size_indexable Application.get_env(:nomure, :max_string_size_indexable, 16)

  def insert_properties(tr, uid, node_data, %State{
        properties: properties_dir
      })
      when is_map(node_data) do
    Enum.each(
      node_data,
      fn
        {:uid, _value} ->
          nil

        {key, value} ->
          Utils.set_transaction(tr, {uid, key |> Atom.to_string()}, value, properties_dir)
      end
    )

    Utils.set_transaction(tr, {uid, "uid"}, nil, properties_dir)
  end

  def index_properties(_tr, _uid, [], _state) do
    nil
  end

  def index_properties(tr, uid, node_data, %State{
        properties_index: properties_index_dir
      }) do
    index_property(tr, uid, node_data, properties_index_dir)
  end

  defp index_property(
         tr,
         uid,
         node_data,
         properties_index_dir
       ) do
    data = get_indexable_properties(node_data)

    Enum.each(
      data,
      fn
        {key, value} ->
          Utils.set_transaction(
            tr,
            {key |> Atom.to_string(), value, uid},
            nil,
            properties_index_dir
          )
      end
    )
  end

  # get the indexable properties
  # for the moment the only valid index properties are
  # integer, float, boolean and user defined string length (default 16)
  # be careful, don't set string size too big, because will cause performance problems
  defp get_indexable_properties(node_data) do
    node_data
    |> Enum.reduce(%{}, fn
      {key, value}, acc when is_integer(value) ->
        Map.put(acc, key, {:integer, value})

      {key, value}, acc when is_float(value) ->
        Map.put(acc, key, {:float32, value})

      {key, value}, acc when is_boolean(value) ->
        Map.put(acc, key, {:boolean, value})

      {key, value}, acc
      when is_binary(value) and byte_size(value) <= @max_string_size_indexable ->
        Map.put(acc, key, {:unicode_string, value})

      _, acc ->
        acc
    end)
  end
end
