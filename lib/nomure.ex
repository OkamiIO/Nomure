defmodule Nomure do
  @moduledoc """
  Documentation for Nomure.
  """

  @doc """
  Starts the database
  """
  defdelegate start(), to: Nomure.Database
end
