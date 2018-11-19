defmodule Nomure.Schema.ParentNode do
  @enforce_keys [:node_name, :node_data]
  defstruct [:node_name, :node_data, :node_relationships]
end
