defmodule Nomure.Node do
  alias Nomure.Node.{Server, State}
  alias Nomure.Database.State, as: DatabaseState

  def new(db, node_name) do
    Server.start_link(get_name(node_name), State.from(node_name, DatabaseState.from(db)))
  end

  def create_node_with_transaction(%FDB.Transaction{} = tr, data, node_name) do
    GenServer.call(get_name(node_name), {:create_node, tr, data})
  end

  def create_node(db, data, node_name) do
    GenServer.call(get_name(node_name), {:create_node_transaction, db, data})
  end

  def node_uid_present?(tr, uid, node_name) do
    GenServer.call(get_name(node_name), {:node_uid_present?, tr, uid})
  end

  @spec get_name(String.t()) :: {:via, Registry, {Registry.GraphNodeNames, any()}}
  def get_name(node_name) do
    {:via, Registry, {Registry.GraphNodeNames, node_name}}
  end
end
