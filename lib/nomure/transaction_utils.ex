defmodule Nomure.TransactionUtils do
  import FDB.Option
  alias FDB.Transaction

  @database_state_key :node_state
  @uid_size Application.get_env(:nomure, :uid_key_size, 64)

  def get_database_state_key, do: @database_state_key

  @doc """
  Set the transaction with the given key and value, it changes the coder based in the dir parameter
  """
  @spec set_transaction(FDB.Transaction.t(), any(), any(), FDB.Database.t()) ::
          FDB.Transaction.t()
  def set_transaction(tr, key, value, dir) do
    Transaction.set(
      tr,
      key,
      value,
      get_coder_options(dir)
    )

    tr
  end

  def get_transaction(tr, key, dir) do
    result = Transaction.get(tr, key, get_coder_options(dir))

    {:ok, tr, result}
  end

  def add_and_get_counter(tr, key, addition \\ 1) when is_number(addition) do
    Transaction.atomic_op(
      tr,
      key,
      mutation_type_add(),
      <<addition::little-integer-unsigned-size(@uid_size)>>,
      %{coder: FDB.Transaction.Coder.new()}
    )

    <<counter::little-integer-unsigned-size(@uid_size)>> = Transaction.get(tr, key)
    counter
  end

  defp get_coder_options(dir) do
    %{coder: dir.coder}
  end
end
