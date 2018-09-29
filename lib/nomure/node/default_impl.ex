defmodule Nomure.Node.DefaultImpl do
  import Nomure.Schema.Property.Guards

  alias Nomure.Schema.{ParentNode}
  alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Node.State
  alias Nomure.Database.State, as: DatabaseState

  # nomure:node:uid
  @uid_space "n:n:u"

  def insert_data(tr, %ParentNode{} = parent_node, %State{} = state) do
    uid = get_new_uid(tr, parent_node)

    insert_properties(tr, uid, parent_node, state)
  end

  def update_field(tr, uid, key, value) do
  end

  def delete_node(tr, uid) do
  end

  defp get_new_uid(tr, %ParentNode{__node_name__: node_name}) do
    # TODO atomic add counter for global uid
    uid = Utils.add_and_get_counter(tr, @uid_space)
    {node_name, uid}
  end

  defp insert_properties(tr, uid, %ParentNode{} = parent_node, %State{} = state) do
    parent_node
    |> get_valid_properties()
    |> serialize_properties()
    |> compress_serialized_properties()
    |> set_properties_into_database(tr, uid, state)
  end

  defp get_valid_properties(%ParentNode{__node_data__: map}) do
    map
    |> Enum.reject(fn
      {_, value} when is_primitive(value) -> false
      # does we need to throw an exeption for an invalid property?
      {_, _} -> true
    end)
  end

  defp serialize_properties(map) do
    map |> Jason.encode!()
  end

  defp compress_serialized_properties(serialized_properties) do
    serialized_properties |> :zlib.compress()
  end

  defp set_properties_into_database(compressed_data, tr, uid, %State{
         database_state: %DatabaseState{properties: properties_dir}
       }) do
    Utils.set_transaction(tr, uid, compressed_data, properties_dir)
  end
end
