defmodule Nomure.Node.ChunkImpl.Edge.Query do
  def edge(_tr, _state, _uid, _relation_uid, _property_name, edges_select)
      when edges_select in [nil, []] do
    %{}
  end

  def edge(tr, state, uid, relation_uid, property_name, edges_select) do
    Map.new(edges_select, fn edge_name ->
      {edge_name,
       FDB.Transaction.get(
         tr,
         {property_name |> to_string(), uid, relation_uid, edge_name |> to_string()},
         %{
           coder: state.edges
         }
       )}
    end)
  end
end
