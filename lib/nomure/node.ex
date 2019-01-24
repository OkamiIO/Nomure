defmodule Nomure.Node do
  alias Nomure.Node.{Server}
  alias Nomure.Schema.Query
  alias Nomure.Database.State, as: DatabaseState

  def new(db) do
    :persistent_term.put(
      Nomure.TransactionUtils.get_database_state_key(),
      DatabaseState.from(db)
    )
  end

  defdelegate create_node(data), to: Server

  defdelegate create_node(tr, data, state), to: Server

  defdelegate node_exist?(uid, node_name), to: Server

  defdelegate node_exist?(tr, uid, node_name, state), to: Server

  defdelegate query(parent_node), to: Query

  # get_node_uid_by(property_name, value, fields \\ nil) # if nil just rreturn the id, if not return the selected stuff

  # select(uid, fields)

  # get_edge(uid, uid, edge_property)
end
