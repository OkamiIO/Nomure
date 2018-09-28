defmodule Nomure.Node.State do
  @moduledoc false

  @enforce_keys [:node_name, :database_state]
  defstruct [:node_name, :database_state]

  @type t :: %__MODULE__{
          node_name: String.t(),
          database_state: Nomure.Database.State.t()
        }

  @doc """
  Creates a new state for the given node name and schema definition
  """
  @spec from(String.t(), Nomure.Database.State.t()) :: Nomure.Node.State.t()
  def from(node_name, database_state) do
    %__MODULE__{
      node_name: node_name,
      database_state: database_state
    }
  end
end
