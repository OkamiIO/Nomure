defmodule Nomure.Schema.ChildrenNode do
  # :__node_relationships__ TODO does a children need relationships?
  @enforce_keys [:__node_name__, :__node_data__]
  defstruct [:__node_name__, :__edge_data__, :__node_data__]
end
