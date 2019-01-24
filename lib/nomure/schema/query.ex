defmodule Nomure.Schema.Query do
  alias Nomure.Schema.Query.{ParentQuery, ChildrenQuery, UniqueQuery}
  alias Nomure.Schema.Query.Plan.Parser
  alias Nomure.TransactionUtils
  alias Nomure.Schema.Query.Execute

  def query(%UniqueQuery{node_name: node_name, identifier: [id: id], select: fields_list}) do
    TransactionUtils.transact(fn tr, state ->
      # check exist
      # When implemented change if for `with`
      if(Nomure.Node.node_exist?(tr, id, node_name, state)) do
        # query fields

        select_by_uid(tr, state, {node_name, id}, fields_list)
      else
        # do we return an error?
        nil
      end
    end)
  end

  def query(%ParentQuery{node_name: node_name, where: statements, select: fields_list}) do
    query_plan = Parser.parse(statements)

    TransactionUtils.transact(fn tr, state ->
      case Execute.where(tr, state, node_name, nil, query_plan) do
        [] ->
          nil

        uids ->
          Enum.map(uids, &select_by_uid(tr, state, &1, fields_list))
      end
    end)
  end

  defp select_by_uid(tr, state, {node_name, id}, fields_list) do
    Map.new(fields_list, fn
      # if ChildrenQuery, evaluate __where__, get ids, query ids
      {_field, %ChildrenQuery{}} ->
        # if where is nil, get all the childrens and select data
        # if where isn't nil then query those nodes based on the given conditions
        nil

      :id ->
        {:id, id}

      # if atom get property
      field when is_atom(field) ->
        {
          field,
          FDB.Transaction.get(tr, {{node_name, id}, field |> to_string()}, %{
            coder: state.properties.coder
          })
        }
    end)
  end
end
