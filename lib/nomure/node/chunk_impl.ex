defmodule Nomure.Node.ChunkImpl do
  alias Nomure.Schema.{ParentNode, ChildrenNode}
  alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Database.State
  alias Nomure.Node.ChunkImpl.{Property, Vertex}

  def insert_data(
        tr,
        %ParentNode{node_data: node_data, node_relationships: relationships} = node,
        %State{} = state
      ) do
    uid = get_new_uid(tr, node, state)

    insert_and_index_properties(tr, uid, node_data, state)

    relation_uids =
      if relationships not in [nil, []] do
        Vertex.insert_relationships(tr, uid, relationships, state)
      else
        %{}
      end

    {uid, relation_uids}
  end

  # Children only insert properties
  def insert_data(
        tr,
        %ChildrenNode{node_data: node_data} = node,
        %State{} = state
      ) do
    uid = get_new_uid(tr, node, state)

    insert_and_index_properties(tr, uid, node_data, state)

    {uid, %{}}
  end

  defp insert_and_index_properties(tr, uid, node_data, state) do
    Property.insert_properties(tr, uid, node_data, state)
    Property.Indexer.index_properties(tr, uid, node_data, state)
  end

  defp get_new_uid(tr, %{node_name: node_name}, state) do
    uid = Utils.get_new_uid(tr, state)
    {node_name, uid}
  end
end
