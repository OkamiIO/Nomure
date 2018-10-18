defmodule Nomure.Node.DefaultImpl do
  import Nomure.Schema.Property.Guards

  alias Nomure.Schema.{ParentNode, ChildrenNode}
  alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Database.State

  # nomure:node:uid
  @uid_space "n:n:u"

  def insert_data(tr, %ParentNode{} = node, %State{} = state) do
    uid = get_new_uid(tr, node)

    insert_properties(tr, uid, node, state)
    insert_nodes(tr, uid, node, state)
  end

  def insert_data(tr, %ChildrenNode{} = node, %State{} = state) do
    uid = get_new_uid(tr, node)

    insert_properties(tr, uid, node, state)
  end

  def update_field(tr, uid, key, value) do
  end

  def delete_node(tr, uid) do
  end

  defp get_new_uid(tr, %{__node_name__: node_name}) do
    uid = Utils.add_and_get_counter(tr, @uid_space)
    {node_name, uid}
  end

  defp insert_properties(tr, uid, %{} = parent_node, %State{} = state) do
    parent_node
    |> validate_properties()
    |> serialize_properties()
    |> compress_serialized_properties()
    |> set_properties_into_database(tr, uid, state)
  end

  defp validate_properties(%{__node_data__: map}) do
    # TODO do we need to split the logic that does not involve transactions?
    # tho it makes harder to reason about it
    map
    |> Enum.reject(fn
      {_, value} when is_primitive(value) ->
        false

      {key, [%Nomure.Schema.Property.I18NString{}] = value} ->
        not all_i18n?(key, value)

      # please send a valid data
      {key, value} ->
        raise_property_error(key, value)
    end)
  end

  defp all_i18n?(key, map) do
    Enum.all?(map, fn
      %Nomure.Schema.Property.I18NString{} -> true
      _ -> raise_property_error(key, map)
    end)
  end

  defp serialize_properties(map) do
    map |> Jason.encode!()
  end

  defp compress_serialized_properties(serialized_properties) do
    serialized_properties |> :zlib.compress()
  end

  defp set_properties_into_database(compressed_data, tr, uid, %State{
         properties: properties_dir
       }) do
    Utils.set_transaction(tr, uid, compressed_data, properties_dir)
  end

  defp insert_nodes(tr, uid, %ParentNode{} = parent_node, %State{} = state) do
    parent_node
    |> validate_relationship()
    |> Enum.each(fn {key, value} -> insert_node(tr, state, uid, key, value) end)
  end

  defp validate_relationship(%ParentNode{__node_relationships__: relationship}) do
    relationship
    |> Enum.all?(fn
      {key, [%ChildrenNode{}] = value} -> all_nodes?(key, value)
      {_, <<_uid::little-integer-unsigned-size(128)>>} -> true
      {key, value} -> raise_property_error(key, value)
    end)
  end

  defp all_nodes?(key, map) do
    Enum.all?(map, fn
      %ChildrenNode{} -> true
      _ -> raise_property_error(key, map)
    end)
  end

  defp insert_node(
         tr,
         %State{
           out_nodes: out_dir
         } = state,
         uid,
         edge_name,
         %ChildrenNode{
           __node_name__: node_name,
           __node_data__: <<relation_uid::little-integer-unsigned-size(128)>>
         } = value
       ) do
    relation_uid = {node_name, relation_uid}
    # check exist
    node_exist?(tr, relation_uid, node_name, state, edge_name)

    # add edge info
    # add property to database, raise if error
    insert_node_relation(tr, uid, edge_name, relation_uid, out_dir)
  end

  defp node_exist?(tr, relation_uid, node_name, state, edge_name) do
    if not Nomure.Node.node_exist?(tr, relation_uid, node_name, state) do
      raise Nomure.Error.NodeValueError, relation_uid: relation_uid, edge_name: edge_name
    end
  end

  defp insert_node_relation(tr, uid, edge_name, relation_uid, out_dir) do
    Utils.set_transaction(tr, {uid, edge_name, relation_uid}, nil, out_dir)
  end

  defp raise_property_error(key, value) do
    raise Nomure.Error.PropertyValueError, property_name: key, value: value
  end
end
