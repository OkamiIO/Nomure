defmodule Nomure.TransactionUtils do
  import FDB.Option

  alias FDB.{Database, Transaction}
  alias FDB.Directory.HighContentionAllocator

  @database_state_key :graph_state
  @atomic_coder FDB.Transaction.Coder.new()

  def get_database_state_key, do: @database_state_key

  def transact(func) when is_function(func, 2) do
    state = Nomure.Database.get_state()

    Database.transact(state.db, fn tr -> func.(tr, state) end)
  end

  def clear_transaction(tr, key, dir) do
    Transaction.clear(tr, key, get_coder_options(dir))
  end

  @doc """
  Set the transaction with the given key and value, it changes the coder based in the dir parameter
  """
  @spec set_transaction(FDB.Transaction.t(), any(), any(), FDB.Database.t()) ::
          :ok
  def set_transaction(tr, key, value, coder) do
    Transaction.set(
      tr,
      key,
      value,
      get_coder_options(coder)
    )
  end

  def get_transaction(tr, key, coder) do
    result = Transaction.get(tr, key, get_coder_options(coder))

    {:ok, tr, result}
  end

  def get_new_uid(tr, state) do
    {a, _} =
      HighContentionAllocator.allocate(state.uid_hca.directory, tr)
      # nil dummy value
      |> FDB.Coder.Integer.decode(nil)

    a
  end

  def add_to_counter(tr, key, addition \\ 1) when is_integer(addition) do
    Transaction.atomic_op(
      tr,
      key,
      mutation_type_add(),
      # 64 bits (8 bytes) counter as documentation mentions
      <<addition::little-integer-unsigned-size(64)>>,
      %{coder: @atomic_coder}
    )
  end

  defp get_coder_options(coder) do
    %{coder: coder}
  end
end
