defmodule Nomure.Node.ChunkImpl.Edge do
  alias Nomure.TransactionUtils, as: Utils

  def insert_edge(tr, uid, relation_uid, edge_name, edge_data, edge_dir) do
    Enum.map(edge_data, fn
      {key, value} ->
        Utils.set_transaction(
          tr,
          {edge_name |> Atom.to_string(), uid, relation_uid, key |> Atom.to_string()},
          value,
          edge_dir
        )
    end)
  end
end
