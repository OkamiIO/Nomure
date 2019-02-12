defmodule Nomure.Node.ChunkImpl.Vertex.Query do
  alias FDB.{KeySelectorRange, Transaction}

  def relationships(tr, state, {_node_name, _node_uid} = uid, edge_name, nil, limit \\ 0) do
    range = KeySelectorRange.starts_with({uid, edge_name |> to_string()})

    Transaction.get_range(tr, range, %{coder: state.out_nodes, limit: limit})
    |> Enum.to_list()
    |> Enum.map(&get_uid_from_encoded/1)
  end

  defp get_uid_from_encoded({{_, _, timestamp, relation_uid}, "nil"}) do
    {timestamp, relation_uid}
  end
end
