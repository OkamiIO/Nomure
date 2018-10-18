defmodule Nomure.Node.ChunkImpl do
  alias Nomure.Schema.{ParentNode, ChildrenNode}
  alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Database.State

  # nomure:node:uid
  @uid_space "n:n:u"

  def insert_data(tr, %ParentNode{__node_data__: node_data} = node, %State{} = state) do
    uid = get_new_uid(tr, node)

    insert_properties(tr, uid, node_data, state)
  end

  defp get_new_uid(tr, %{__node_name__: node_name}) do
    uid = Utils.add_and_get_counter(tr, @uid_space)
    {node_name, uid}
  end

  defp insert_properties(tr, uid, node_data, %State{
         properties: properties_dir
       })
       when is_map(node_data) do
    Enum.each(
      node_data,
      fn
        {key, value} -> Utils.set_transaction(tr, {uid, key}, value, properties_dir)
      end
    )
  end
end
