defprotocol Nomure.Schema.Query do
  def query(query_map)
end

defimpl Nomure.Schema.Query, for: Nomure.Schema.Query.UniqueQuery do
  alias Nomure.TransactionUtils
  alias Nomure.Node.ChunkImpl.Node.Query

  def query(%{node_name: node_name, identifier: [id: id], select: fields_list}) do
    TransactionUtils.transact(fn tr, state ->
      if(Nomure.Node.node_exist?(tr, id, node_name, state)) do
        Query.select_by_uid(tr, state, {node_name, id}, fields_list)
      else
        # do we return an error?
        nil
      end
    end)
  end

  def query(%{
        node_name: node_name,
        identifier: [{property_name, property_value}],
        select: fields_list
      }) do
    TransactionUtils.transact(fn tr, state ->
      Nomure.Node.ChunkImpl.Property.Query.indexed_values(
        tr,
        state,
        node_name,
        property_name,
        property_value,
        1
      )
      |> List.first()
      |> case do
        nil ->
          nil

        uid ->
          Query.select_by_uid(tr, state, uid, fields_list)
      end
    end)
  end
end

defimpl Nomure.Schema.Query, for: Nomure.Schema.Query.ParentQuery do
  alias Nomure.Schema.Query.Plan.Parser
  alias Nomure.TransactionUtils
  alias Nomure.Schema.Query.Execute
  alias Nomure.Node.ChunkImpl.Node.Query

  def query(%{node_name: node_name, where: statements, select: fields_list}) do
    query_plan = Parser.parse(statements)

    TransactionUtils.transact(fn tr, state ->
      case Execute.where(tr, state, node_name, nil, query_plan) do
        [] ->
          # do we return an error?
          []

        uids ->
          Enum.map(
            uids,
            &Query.select_by_uid(tr, state, &1, fields_list)
          )
      end
    end)
  end
end
