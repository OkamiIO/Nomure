defmodule Nomure.Node.Server do
  alias Nomure.Database.State
  alias Nomure.TransactionUtils

  def create_node(data) do
    TransactionUtils.transact(fn tr, state ->
      create_node(tr, data, state)
    end)
  end

  def create_node(%FDB.Transaction{} = tr, data, %State{} = state) do
    get_impl().insert_data(tr, data, state)
  end

  def node_exist?(uid, node_name) do
    TransactionUtils.transact(fn tr, state ->
      node_exist?(tr, uid, node_name, state)
    end)
  end

  def node_exist?(
        tr,
        uid,
        node_name,
        %State{
          properties: props_dir
        }
      ) do
    {:ok, _tr, result} = TransactionUtils.get_transaction(tr, {{node_name, uid}, "id"}, props_dir)

    result != nil
  end

  def get_impl() do
    Nomure.Node.ChunkImpl
  end
end
