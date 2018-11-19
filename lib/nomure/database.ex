defmodule Nomure.Database do
  def get_state() do
    [{_key, state} | _] =
      :ets.lookup(:database_state, Nomure.TransactionUtils.get_database_state_key())

    state
  end
end
