defmodule Nomure.Schema.ParentNode do
  @enforce_keys [:__node_name__, :__node_data__]
  defstruct [:__node_name__, :__node_data__, :__node_relationships__]
end
