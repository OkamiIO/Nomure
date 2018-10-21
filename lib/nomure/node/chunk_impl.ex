defmodule Nomure.Node.ChunkImpl do
  alias Nomure.Schema.{ParentNode, ChildrenNode}
  alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Database.State
  alias Nomure.Node.ChunkImpl.{Property, Vertex}

  # nomure:node:uid
  @uid_space "n:n:u"

  def insert_data(
        tr,
        %ParentNode{__node_data__: node_data, __node_relationships__: relationships} = node,
        %State{} = state
      ) do
    uid = get_new_uid(tr, node)

    Property.insert_properties(tr, uid, node_data, state)
    Property.index_properties(tr, uid, node_data, state)

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
        %ChildrenNode{__node_data__: node_data} = node,
        %State{} = state
      ) do
    uid = get_new_uid(tr, node)

    Property.insert_properties(tr, uid, node_data, state)
    Property.index_properties(tr, uid, node_data, state)

    {uid, %{}}
  end

  defp get_new_uid(tr, %{__node_name__: node_name}) do
    uid = Utils.add_and_get_counter(tr, @uid_space)
    {node_name, uid}
  end
end
