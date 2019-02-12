defmodule Nomure.Node do
  alias Nomure.Node.{Server}
  alias Nomure.Schema.Query

  defdelegate create_node(data), to: Server

  defdelegate create_node(tr, data, state), to: Server

  defdelegate node_exist?(uid, node_name), to: Server

  defdelegate node_exist?(tr, uid, node_name, state), to: Server

  defdelegate query(parent_node), to: Query
end
