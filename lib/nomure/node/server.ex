defmodule Nomure.Node.Server do
  alias FDB.{Database}

  alias Nomure.Database.State
  alias Nomure.TransactionUtils

  def create_node_from_state(%FDB.Transaction{} = tr, data, %State{} = state) do
    get_impl().insert_data(tr, data, state)
  end

  def create_node_from_database(%FDB.Database{} = db, data) do
    state = FastGlobal.get(TransactionUtils.get_database_state_key())

    Database.transact(db, fn tr ->
      get_impl().insert_data(tr, data, state)
    end)
  end

  def node_exist?(
        tr,
        <<_raw_uid::little-integer-unsigned-size(128)>> = uid,
        node_name,
        %State{
          properties: props_dir
        }
      ) do
    {:ok, _tr, result} = TransactionUtils.get_transaction(tr, {node_name, uid}, props_dir)

    result != nil
  end

  def get_impl() do
    Nomure.Node.DefaultImpl
  end
end
