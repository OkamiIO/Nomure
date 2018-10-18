defmodule Nomure.Node do
  alias Nomure.Node.Server
  alias Nomure.Database.State, as: DatabaseState
  alias Nomure.TransactionUtils

  def new(db) do
    FastGlobal.put(TransactionUtils.get_database_state_key(), DatabaseState.from(db))
  end

  defdelegate create_node_from_state(tr, data, state), to: Server

  defdelegate create_node_from_database(tr, data), to: Server

  defdelegate node_exist?(tr, ui, node_name, state), to: Server
end
