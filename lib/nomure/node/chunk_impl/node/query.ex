defmodule Nomure.Node.ChunkImpl.Node.Query do
  alias Nomure.Schema.Query.ChildrenQuery

  def select_by_uid(tr, state, {node_name, id}, fields_list) do
    Map.new(fields_list, fn
      # if ChildrenQuery, evaluate __where__, get ids, query ids
      {field, %ChildrenQuery{where: where, select: child_select, edges: edges_select}} ->
        # if where is nil, get all the childrens and select data
        # if where isn't nil then query those nodes based on the given conditions
        nodes =
          Nomure.Node.ChunkImpl.Vertex.Query.relationships(
            tr,
            state,
            {node_name, id},
            field,
            where
          )

        {field,
         %{
           edges:
             Enum.map(
               nodes,
               &(%{
                   cursor: elem(&1, 1) |> elem(1),
                   node: select_by_uid(tr, state, elem(&1, 1), child_select)
                 }
                 |> Map.merge(
                   Nomure.Node.ChunkImpl.Edge.Query.edge(
                     tr,
                     state,
                     {node_name, id},
                     elem(&1, 1),
                     field,
                     edges_select
                   )
                 ))
             )
         }}

      :id ->
        {:id, id}

      :__node_name__ ->
        {:__node_name__, node_name}

      # if atom get property
      field when is_atom(field) ->
        {
          field,
          Nomure.Node.ChunkImpl.Property.Query.get_property_value(tr, state, node_name, id, field)
        }
    end)
  end
end
