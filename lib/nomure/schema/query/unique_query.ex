defmodule Nomure.Schema.Query.UniqueQuery do
  @enforce_keys [:node_name, :identifier, :select]
  defstruct [:node_name, :identifier, :select]
end
