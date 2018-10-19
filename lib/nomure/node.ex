defmodule Nomure.Node do
  alias Nomure.Node.Server
  alias Nomure.Database.State, as: DatabaseState
  alias Nomure.TransactionUtils

  def new(db) do
    :ets.new(:database_state, [:named_table, read_concurrency: true])

    :ets.insert(
      :database_state,
      {TransactionUtils.get_database_state_key(), DatabaseState.from(db)}
    )
  end

  defdelegate create_node(data), to: Server

  defdelegate create_node(tr, data, state), to: Server

  defdelegate node_exist?(ui, node_name), to: Server

  defdelegate node_exist?(tr, ui, node_name, state), to: Server
end
