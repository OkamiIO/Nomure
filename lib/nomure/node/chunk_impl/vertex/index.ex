defmodule Nomure.Node.ChunkImpl.Vertex.Index do
  alias Nomure.TransactionUtils

  def index(tr, %{inverse_nodes: directory}, {node_name, _} = uid, property_name, relation_uid) do
    property_schema = Nomure.Database.get_property_schema(node_name, property_name)

    index(tr, %{inverse_nodes: directory}, property_schema, uid, property_name, relation_uid)
  end

  def index(
        tr,
        %{inverse_nodes: directory},
        %{"type" => "node"},
        uid,
        property_name,
        relation_uid
      ) do
    TransactionUtils.set_transaction(
      tr,
      {relation_uid, property_name |> to_string(), uid},
      nil,
      directory
    )
  end

  def index(tr, %{inverse_nodes: directory}, _, uid, property_name, relation_uid) do
    TransactionUtils.set_transaction(
      tr,
      {relation_uid, property_name |> to_string(), uid},
      nil,
      directory
    )
  end
end
