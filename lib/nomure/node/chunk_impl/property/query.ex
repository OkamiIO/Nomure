defmodule Nomure.Node.ChunkImpl.Property.Query do
  alias Nomure.TransactionUtils

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
    schema = Nomure.Database.get_schema()
    node_name = node_name |> to_string()
    property = property |> to_string()

    {node_name, property,
     {TransactionUtils.get_index_key_value(value, schema, node_name, property)}}
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
end
