defmodule Nomure.TransactionUtils do
  alias FDB.Transaction

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

  defp get_coder_options(dir) do
    %{coder: dir}
  end
end
