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
  # TODO Here the state absolutelly never changes, I think is better to simplify it just by
  # returning the state from the GenServer (as a handle call) and run the process ouside the GenServer process
  # in this way we can avoid bottenecks in the genserver due to concurrent processes reaching it

  # this is important since some transactions can block the GenServer like for example calculating the
  # recommendations of X user based on Y content

  # for it we can just use the Agent module!

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
