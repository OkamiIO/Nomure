defmodule Nomure.Schema.ChildrenNode do
  # :node_relationships TODO does a children need relationships?
  @enforce_keys [:node_name, :node_data]
  defstruct [:node_name, :edge_data, :node_data]
end
