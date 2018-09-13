defmodule Nomure.Node.Server do
  use GenServer

  alias FDB.{Database}

  alias Nomure.Node.Impl

  # Client
  @spec start_link({:via, atom(), any()}, Nomure.Node.State.t()) ::
          :ignore | {:error, any()} | {:ok, pid()}
  def start_link(name, state) do
    GenServer.start_link(__MODULE__, [state], name: name)
  end

  # Server

  @impl true
  def init([state]) do
    {:ok, state}
  end

  @impl true
  def handle_call({:create_node_transaction, db, data}, _from, state) do
    result = Database.transact(db, fn tr -> Impl.set_data(tr, data, state) end)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:create_node, tr, data}, _from, state) do
    result = Impl.set_data(tr, data, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:node_uid_present?, tr, uid}, _from, state) do
    result = Impl.node_exist?(tr, uid, state)
    {:reply, result, state}
  end
end
