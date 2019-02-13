defmodule Nomure.Node.ChunkImpl.Vertex.Query do
  alias FDB.{KeySelectorRange, Transaction}
  alias Nomure.Schema.Query.Plan.Parser
  alias Nomure.Schema.Query.Execute

  def relationships(tr, state, uid, child_node_name, edge_name, statements, limit \\ 0)

  def relationships(
        tr,
        state,
        {_node_name, _node_uid} = uid,
        _child_node_name,
        edge_name,
        nil,
        limit
      ) do
    range = KeySelectorRange.starts_with({uid, edge_name |> to_string()})

    Transaction.get_range(tr, range, %{coder: state.out_nodes, limit: limit})
    |> Enum.to_list()
    |> Enum.map(&get_uid_from_encoded/1)
  end

  def relationships(
        tr,
        state,
        uid,
        child_node_name,
        edge_name,
        statements,
        _limit
      ) do
    query_plan = Parser.parse(statements)

    case Execute.where(tr, state, child_node_name, nil, query_plan) do
      [] ->
        []

      uids ->
        # we cannot limit the results, we need all the relationships in order to compare them
        # because of that this operation is expensive!
        relationships(tr, state, uid, child_node_name, edge_name, nil)
        |> Enum.filter(fn {_timestamp, relation_uid} ->
          relation_uid in uids
        end)
    end
  end

  defp get_uid_from_encoded({{_, _, timestamp, relation_uid}, "nil"}) do
    {timestamp, relation_uid}
  end
end
