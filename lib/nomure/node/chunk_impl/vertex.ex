defmodule Nomure.Node.ChunkImpl.Vertex do
  alias Nomure.TransactionUtils, as: Utils

  alias Nomure.Node
  alias Nomure.Database.State
  alias Nomure.Schema.ChildrenNode
  alias Nomure.Node.ChunkImpl.Edge

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
         %ChildrenNode{
           __node_data__: value,
           __node_name__: relation_name,
           __edge_data__: edge_data
         },
         %State{
           out_nodes: out_nodes_dir,
           inverse_nodes: inverse_nodes_dir,
           edges: edge_dir
         } = state
       )
       when is_integer(value) do
    if Node.node_exist?(tr, value, relation_name, state) do
      add_relationship(tr, uid, edge_name, value, out_nodes_dir)

      index_relationship(tr, value, edge_name, uid, inverse_nodes_dir)

      add_edge(tr, uid, value, edge_name, edge_data, edge_dir)

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
         %ChildrenNode{__edge_data__: edge_data} = relation,
         %State{
           out_nodes: out_nodes_dir,
           inverse_nodes: inverse_nodes_dir,
           edges: edge_dir
         } = state
       ) do
    {relation_uid, _} = Node.create_node(tr, relation, state)

    add_relationship(tr, uid, edge_name, relation_uid, out_nodes_dir)

    index_relationship(tr, relation_uid, edge_name, uid, inverse_nodes_dir)

    add_edge(tr, uid, relation_uid, edge_name, edge_data, edge_dir)

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

  defp index_relationship(tr, relation_uid, edge_name, uid, in_nodes_dir) do
    Utils.set_transaction(
      tr,
      {relation_uid, edge_name |> Atom.to_string(), uid},
      nil,
      in_nodes_dir
    )
  end

  defp add_edge(_tr, _uid, _edge_name, _relation_uid, edge_data, _edge_dir)
       when edge_data in [nil, %{}] do
    nil
  end

  defp add_edge(tr, uid, relation_uid, edge_name, edge_data, edge_dir) do
    Edge.insert_edge(tr, uid, relation_uid, edge_name, edge_data, edge_dir)
  end
end
