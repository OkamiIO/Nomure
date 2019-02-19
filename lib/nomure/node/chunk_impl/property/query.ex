defmodule Nomure.Node.ChunkImpl.Property.Query do
  alias FDB.{KeySelectorRange, Transaction}

  def get_all_properties_value(tr, state, node_name, id) do
    range = KeySelectorRange.starts_with({{node_name, id}})

    Transaction.get_range(tr, range, %{coder: state.properties})
    |> Enum.to_list()
    |> Enum.map(&get_prop_and_value_from_encoded/1)
  end

  def get_property_value(tr, state, node_name, id, property_name) do
    FDB.Transaction.get(tr, {{node_name, id}, property_name |> to_string()}, %{
      coder: state.properties
    })
  end

  def indexed_values(tr, state, node_name, property_name, value, limit \\ 0) do
    range = KeySelectorRange.starts_with(get_query_index_key(node_name, property_name, value))

    get_property_index_range(tr, state, range, limit)
  end

  def get_query_index_key(node_name, property, value) do
    node_name = node_name |> to_string()
    property = property |> to_string()
    schema = Nomure.Database.get_property_schema(node_name, property)

    {node_name, property, {get_index_key_value(value, schema)}}
  end

  def get_property_index_range(tr, state, range, limit \\ 0) do
    Transaction.get_range(tr, range, %{coder: state.properties_index, limit: limit})
    |> Enum.to_list()
    # cleanup the result list
    |> Enum.map(&get_uid_from_encoded/1)
  end

  # date and time serialization
  defp get_uid_from_encoded({{node_name, _, {_, _, _, {_, uid}}}, "nil"}) do
    {node_name, uid}
  end

  defp get_uid_from_encoded({{node_name, _, {_, {_, uid}}}, "nil"}) do
    {node_name, uid}
  end

  defp get_prop_and_value_from_encoded({{_, property_name}, value}) do
    {property_name |> String.to_existing_atom(), value}
  end

  def get_index_key_value(_value, nil), do: throw("No schema set for the given field")

  def get_index_key_value(value, %{"type" => "integer"}) when is_integer(value),
    do: {:integer, value}

  def get_index_key_value(value, %{"type" => "float"}) when is_float(value), do: {:float32, value}

  def get_index_key_value(value, %{"type" => "boolean"}) when is_boolean(value),
    do: {:boolean, value}

  def get_index_key_value(value, property_schema) when is_binary(value) do
    case property_schema do
      %{"type" => "datetime"} ->
        get_date_time_key_value(value)

      %{"type" => "date"} ->
        get_date_key_value(value)

      %{"type" => "time"} ->
        get_time_key_value(value)

      %{"type" => "enum", "values" => values} ->
        case values[value] do
          nil ->
            throw("Given enum value #{inspect(value)} is not a valid enum property")

          enum_value ->
            {:integer, enum_value}
        end

      %{"type" => "string"} ->
        {:unicode_string, value}
    end
  end

  defp get_date_time_key_value(
         <<year::binary-4, "-", month::binary-2, "-", day::binary-2, "T", hour::binary-2, ":",
           minute::binary-2, ":", second::binary-2, _rest::binary>>
       ) do
    {:nested,
     {{:nested,
       {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()},
        {:integer, day |> parse_integer()}}},
      {:nested,
       {{:integer, hour |> parse_integer()}, {:integer, minute |> parse_integer()},
        {:integer, second |> parse_integer()}}}}}
  end

  defp get_date_time_key_value(<<year::binary-4, "-", month::binary-2, "-", day::binary-2>>) do
    {:nested,
     {{:nested,
       {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()},
        {:integer, day |> parse_integer()}}}}}
  end

  defp get_date_time_key_value(<<year::binary-4, "-", month::binary-2>>) do
    {:nested,
     {{:nested, {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()}}}}}
  end

  defp get_date_time_key_value(<<year::binary-4>>) do
    {:nested, {{:nested, {{:integer, year |> parse_integer()}}}}}
  end

  defp get_date_key_value(<<year::binary-4, "-", month::binary-2, "-", day::binary-2>>) do
    {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()},
     {:integer, day |> parse_integer()}}
  end

  defp get_date_key_value(<<year::binary-4, "-", month::binary-2>>) do
    {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()}}
  end

  defp get_date_key_value(<<year::binary-4>>) do
    {{:integer, year |> parse_integer()}}
  end

  defp get_time_key_value(<<hour::binary-4, ":", minute::binary-2, ":", second::binary-2>>) do
    {{:integer, hour |> parse_integer()}, {:integer, minute |> parse_integer()},
     {:integer, second |> parse_integer()}}
  end

  defp get_time_key_value(<<hour::binary-4, ":", minute::binary-2>>) do
    {{:integer, hour |> parse_integer()}, {:integer, minute |> parse_integer()}}
  end

  defp get_time_key_value(<<hour::binary-4>>) do
    {{:integer, hour |> parse_integer()}}
  end

  defp parse_integer(value) do
    value |> Integer.parse() |> elem(0)
  end
end
