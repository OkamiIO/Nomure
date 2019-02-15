defmodule Nomure.Node.ChunkImpl.Property do
  alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Database.State
  alias Nomure.Node.ChunkImpl.Property.Query

  def insert_properties(tr, {node_name, _} = uid, node_data, %State{
        properties: properties_dir
      })
      when is_map(node_data) do
    Enum.each(
      node_data,
      fn
        {:id, _value} ->
          # TODO is this really necesary? We always override uid at the end of the function...
          :ok

        {property_name, value} ->
          property_name = property_name |> to_string()
          property_schema = Nomure.Database.get_property_schema(node_name, property_name)

          value =
            case check_value_type_index(property_schema, uid, property_name, value) do
              :ok -> value
              new_value -> new_value
            end

          Utils.set_transaction(tr, {uid, property_name}, value, properties_dir)
      end
    )

    Utils.set_transaction(tr, {uid, "id"}, nil, properties_dir)
  end

  def check_value_type_index(nil, {_node_name, _node_uid}, property_name, _value) do
    # no schema setup so just return :ok
    throw("Given property name (#{property_name}) does not exist at the schema definition")
  end

  def check_value_type_index(property_schema, {node_name, _node_uid}, property_name, value) do
    return_value =
      case property_schema do
        %{"type" => "integer"} when is_integer(value) ->
          :ok

        %{"type" => "float"} when is_float(value) ->
          :ok

        %{"type" => "boolean"} when is_boolean(value) ->
          :ok

        %{"type" => "string"} when is_binary(value) ->
          :ok

        %{"type" => "list"} when is_list(value) ->
          :ok

        %{"type" => "datetime"} ->
          case value do
            %DateTime{} ->
              :ok

            _ ->
              throw_not_valid_schema_value("datetime", property_name, value)
          end

        %{"type" => "date"} ->
          case value do
            %Date{} ->
              :ok

            _ ->
              throw_not_valid_schema_value("date", property_name, value)
          end

        %{"type" => "time"} ->
          case value do
            %Time{} ->
              :ok

            _ ->
              throw_not_valid_schema_value("time", property_name, value)
          end

        %{"type" => "enum", "values" => values} ->
          case values[value] do
            enum_value when is_integer(enum_value) ->
              enum_value

            _ ->
              throw_not_valid_schema_value("enum", property_name, value)
          end

        %{"type" => type} ->
          throw_not_valid_schema_value(type, property_name, value)

        _ ->
          throw(
            "Given value does not fit the property schema definition (no metadata available - #{
              value
            })"
          )
      end

    check_value_type_index_uniqueness(
      property_schema,
      node_name,
      property_name,
      value,
      return_value
    )
  end

  defp check_value_type_index_uniqueness(
         %{"index" => ["unique"]},
         node_name,
         property_name,
         value,
         return_value
       ) do
    # TODO do we really need to create another transaction?
    Utils.transact(fn tr, state ->
      Query.indexed_values(tr, state, node_name, property_name, value, 1)
    end)
    |> Enum.any?()
    |> case do
      true ->
        throw("Value already exist!")

      _ ->
        return_value
    end
  end

  defp check_value_type_index_uniqueness(_, _node_name, _property_name, _value, return_value) do
    return_value
  end

  defp throw_not_valid_schema_value(type, property_name, value) do
    throw(
      "Given value does not fit the property schema definition (#{inspect(type)} - #{
        inspect(property_name)
      } - #{inspect(value)})"
    )
  end
end
