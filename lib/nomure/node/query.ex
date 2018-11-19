defmodule Nomure.Node.Query do
  alias FDB.{Database}
  alias Nomure.Schema.Query.{ParentQuery, ChildrenQuery}

  # TODO create a parent query for single result and another for list!
  def query(%ParentQuery{node_name: node_name, where: [id: id], select: fields_list}) do
    state = Nomure.Database.get_state()

    Database.transact(state.db, fn tr ->
      # check exist
      # When implemented change if for `with`
      if(Nomure.Node.node_exist?(tr, id, node_name, state)) do
        # query fields

        Map.new(fields_list, fn
          # if ChildrenQuery, evaluate __where__, get ids, query ids
          %ChildrenQuery{} ->
            nil

          # if atom get property
          field when is_atom(field) ->
            {
              field,
              FDB.Transaction.get(tr, {{node_name, id}, field |> Atom.to_string()}, %{
                coder: state.properties.coder
              })
            }
        end)
      else
        # return an error
        nil
      end
    end)
  end

  def query(%ParentQuery{where: where}) do
    # parse where query, optimize it
    state = Nomure.Database.get_state()

    Database.transact(state.db, fn tr ->
      range = FDB.KeySelectorRange.starts_with({"name", {:unicode_string, "Sif"}})

      FDB.Transaction.get_range(tr, range, %{coder: state.properties_index.coder})
      |> Enum.to_list()
    end)
  end
end
