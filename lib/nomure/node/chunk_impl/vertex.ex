defmodule Nomure.Node.ChunkImpl.Vertex do
  alias Nomure.TransactionUtils, as: Utils

  alias Nomure.Node
  alias Nomure.Database.State
  alias Nomure.Schema.ChildrenNode

  def insert_relationships(
        tr,
        uid,
        relationships,
        state
      ) do
    # must return a list with the relationship uids
    Enum.reduce(relationships, %{}, fn
      {key, value}, acc ->
        result =
          Enum.map(value, fn %ChildrenNode{} = children ->
            insert_relationship(tr, uid, key, children, state)
          end)

        Map.put(acc, key, result)
    end)
  end

  # The user can give only the relation id wihtout creating the record
  defp insert_relationship(
         tr,
         uid,
         edge_name,
         %ChildrenNode{__node_data__: value, __node_name__: relation_name},
         %State{
           out_nodes: out_nodes_dir
         } = state
       )
       when is_integer(value) do
    if Node.node_exist?(tr, value, relation_name, state) do
      add_relationship(tr, uid, edge_name, value, out_nodes_dir)
      # TODO Edge
      value
    else
      raise Nomure.Error.NodeValueError, relation_uid: value, edge_name: edge_name
    end
  end

  # Or just creating the record itself
  defp insert_relationship(
         tr,
         uid,
         edge_name,
         %ChildrenNode{} = relation,
         %State{
           out_nodes: out_nodes_dir
         } = state
       ) do
    relation_uid = Node.create_node(tr, relation, state)

    add_relationship(tr, uid, edge_name, relation_uid, out_nodes_dir)

    # TODO Edge
    relation_uid
  end

  defp add_relationship(tr, uid, edge_name, relation_uid, out_nodes_dir) do
    Utils.set_transaction(
      tr,
      {uid, edge_name |> Atom.to_string(), relation_uid},
      nil,
      out_nodes_dir
    )
  end
end
