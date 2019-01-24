defmodule Nomure.Database do
  def get_state() do
    :persistent_term.get(Nomure.TransactionUtils.get_database_state_key())
  end
end
