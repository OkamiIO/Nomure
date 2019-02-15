defmodule Nomure.Node.ChunkImpl.Property.Indexer do
  # alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Database.State

  # alias FDB.{KeySelectorRange, Transaction}

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
         {node_name, uid},
         node_data,
         properties_index_dir
       ) do
    data = get_indexable_properties(node_name, node_data)

    Task.async_stream(
      data,
      fn
        {key, value} ->
          property_name = key |> to_string()

          Nomure.TransactionUtils.set_transaction(
            tr,
            {node_name, property_name, {value, {:integer, uid}}},
            nil,
            properties_index_dir
          )

          # insert_index_property(tr, node_name, uid, key, value, properties_index_dir)
      end
    )
    |> Stream.run()
  end

  # get the indexable properties
  # for the moment the only valid index properties are
  # integer, float, boolean and user defined string length
  # be careful, don't set string size too big, because will cause performance problems
  defp get_indexable_properties(node_name, node_data) do
    schema = Nomure.Database.get_schema()[node_name]
    _get_indexable_properties(schema, node_data)
  end

  defp _get_indexable_properties(nil, _node_data) do
    throw("No schema data for the given node")
  end

  defp _get_indexable_properties(node_schema, node_data) do
    node_data
    |> Enum.reduce(%{}, fn
      {key, value}, acc ->
        key = to_string(key)

        get_index_definition(node_schema[key], key, value)
        |> case do
          nil ->
            acc

          index_definition ->
            Map.put(acc, key, index_definition)
        end
    end)
  end

  defp get_index_definition(nil, key, _value) do
    throw("No schema for the property name #{key}")
  end

  defp get_index_definition(property_schema, _key, value) do
    case property_schema do
      %{"type" => "integer", "index" => index}
      when index in [true, "unique"] and is_integer(value) ->
        {:integer, value}

      %{"type" => "float", "index" => index}
      when index in [true, "unique"] and is_float(value) ->
        {:float32, value}

      %{"type" => "boolean", "index" => index}
      when index in [true, "unique"] and is_boolean(value) ->
        {:boolean, value}

      %{"type" => "enum", "index" => index, "values" => values}
      when index in [true, "unique"] and is_binary(value) ->
        case values[value] do
          enum_value when is_integer(enum_value) ->
            {:integer, enum_value}

          _ ->
            nil
        end

      %{"type" => "datetime", "index" => index}
      when index in [true, "unique"] and is_map(value) ->
        {:nested,
         {{:nested, {{:integer, value.year}, {:integer, value.month}, {:integer, value.day}}},
          {:nested, {{:integer, value.hour}, {:integer, value.minute}, {:integer, value.second}}}}}

      %{"type" => "date", "index" => index}
      when index in [true, "unique"] and is_map(value) ->
        {{:integer, value.year}, {:integer, value.month}, {:integer, value.day}}

      %{"type" => "time", "index" => index}
      when index in [true, "unique"] and is_map(value) ->
        {{:integer, value.hour}, {:integer, value.minute}, {:integer, value.second}}

      %{"type" => "string", "index" => index}
      when is_binary(value) and (index == ["exact"] or index == ["unique"]) ->
        # todo implement remaining indexes
        {:unicode_string, value}

      _ ->
        nil
    end
  end

  # defp insert_index_property(
  #        tr,
  #        node_name,
  #        uid,
  #        key,
  #        value,
  #        properties_index_dir
  #      ) do
  #   # todo make this an api call
  #   key = key |> to_string()
  #   value_size = Msgpax.pack!(uid) |> IO.iodata_to_binary() |> byte_size()

  #   data =
  #     Transaction.get_range(
  #       tr,
  #       KeySelectorRange.starts_with({node_name, key, {value}}),
  #       %{coder: properties_index_dir, snapshot: true}
  #     )
  #     # filter keys that can hold the value
  #     |> Stream.filter(fn {{_, _, {_, _}}, values} ->
  #       size = Msgpax.pack!(values) |> IO.iodata_to_binary() |> byte_size()
  #       size + value_size <= 10000
  #     end)
  #     |> Enum.to_list()

  #   case data do
  #     [] ->
  #       # create the key
  #       create_new_index_property(
  #         tr,
  #         node_name,
  #         uid,
  #         key,
  #         value,
  #         properties_index_dir
  #       )

  #     # add the value to a key that has
  #     ^data ->
  #       data
  #       # we get the frist in the list, if it's nil then we create another space
  #       # if not, we delete the exiting key and create another one with the new value
  #       |> List.first()
  #       |> case do
  #         nil ->
  #           create_new_index_property(
  #             tr,
  #             node_name,
  #             uid,
  #             key,
  #             value,
  #             properties_index_dir
  #           )

  #         current_key ->
  #           override_index_property(current_key, tr, uid, properties_index_dir)
  #       end
  #   end
  # end

  # # no space available on the actual keys so we create a new one
  # defp create_new_index_property(
  #        tr,
  #        node_name,
  #        uid,
  #        key,
  #        value,
  #        properties_index_dir
  #      ) do
  #   # TODO do we check if the key with the given uid already exist?
  #   Utils.set_transaction(
  #     tr,
  #     {node_name, key, {value, {:integer, uid}}},
  #     [uid],
  #     properties_index_dir
  #   )
  # end

  # # theres space on the given key, so we delete the old key and create a new one with the new size
  # defp override_index_property(
  #        {{node_name, key, {key_value, {:integer, key_uid}}} = node_key, current_values},
  #        tr,
  #        uid,
  #        properties_index_dir
  #      ) do
  #   # :ok =
  #   #   Transaction.add_conflict_key(tr, node_key, Option.conflict_range_type_write(), %{
  #   #     coder: properties_index_dir
  #   #   })

  #   # :ok =
  #   #   Utils.clear_transaction(
  #   #     tr,
  #   #     node_key,
  #   #     properties_index_dir
  #   #   )

  #   Utils.set_transaction(
  #     tr,
  #     {node_name, key, {key_value, {:integer, key_uid}}},
  #     [uid | current_values],
  #     properties_index_dir
  #   )
  # end
end
