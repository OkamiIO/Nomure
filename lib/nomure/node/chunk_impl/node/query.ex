defmodule Nomure.Node.ChunkImpl.Node.Query do
  alias Nomure.Schema.Query.ChildrenQuery

  def select_by_uid(tr, state, {node_name, id}, fields_list) when fields_list in [nil, []] do
    Nomure.Node.ChunkImpl.Property.Query.get_all_properties_value(tr, state, node_name, id)
    |> Map.new()
    |> Map.put(:id, id)
    |> Map.put(:__node_name__, node_name)
  end

  def select_by_uid(tr, state, {node_name, id}, fields_list) do
    Map.new(fields_list, fn
      # if ChildrenQuery, evaluate __where__, get ids, query ids
      {_field, %ChildrenQuery{}} = property ->
        query_childs(tr, state, property, {node_name, id})

      :id ->
        {:id, id}

      :__node_name__ ->
        {:__node_name__, node_name}

      # if atom get property
      field when is_atom(field) ->
        {
          field,
          Nomure.Node.ChunkImpl.Property.Query.get_property_value(tr, state, node_name, id, field)
          |> check_value_transformation(
            Nomure.Database.get_property_schema(node_name, field |> to_string)
          )
        }
    end)
  end

  defp check_value_transformation(value, %{"type" => "enum", "values" => values}) do
    case Enum.filter(values, fn {_, enum_value} -> enum_value == value end) do
      [] ->
        value

      [{enum_name, _}] ->
        enum_name
    end
  end

  defp check_value_transformation(value, _) do
    value
  end

  defp query_childs(
         tr,
         state,
         {field,
          %ChildrenQuery{
            node_name: child_node_name,
            where: where,
            select: child_select,
            edges: edges_select
          }},
         {node_name, id}
       ) do
    nodes =
      Nomure.Node.ChunkImpl.Vertex.Query.relationships(
        tr,
        state,
        {node_name, id},
        child_node_name,
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
  end
end
