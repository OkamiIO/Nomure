defmodule Nomure.Node.Impl do
  alias Nomure.Node.State
  alias Nomure.TransactionUtils, as: Utils

  @type uid :: non_neg_integer()
  @type property_name :: String.t()
  @type value :: any()

  def set_data(tr, _data, _impl) do
    # params:
    #   data: a map with the values to be set on the database

    # Iterate the data map
    # Check if have indexes, like unique etc (Implementation on Property module)
    #   - if index fails, return error
    # Check the property type
    #   - if primitive set_property
    #   - if node set_out_edges
    #     - check if the value is primitive or a map
    # Check for properties that does not exist or null and set the dafault if applies
    {:ok, tr, 0}
  end

  def node_exist?(tr, uid, %State{props: props_dir}) do
    {:ok, tr, result} = Utils.get_transaction(tr, {uid, "uid"}, props_dir)

    {:ok, tr, result != nil}
  end

  def set_property(tr, uid, %{__struct__: property_type} = property, value, %State{} = state) do
    # (uid, property_name) = value
    property_type.set_property(property, tr, state, {uid, value})
  end

  @doc """
  Set an index to the property, basically you can get the uid of nodes by an X property value

  By default all properties with primitive values are indexed (except string types)

    `(property_name, value, uid) = ''`
  """
  def set_property_index(
        tr,
        uid,
        %{__struct__: property_type} = property,
        value,
        %State{} = state
      ) do
    property_type.set_index(property, tr, state, {uid, value})
  end

  def set_out_edges(tr, uid, edge_name, edge_id, relation_node_uid, %State{
        out_edges: out_edges
      }) do
    # (uid, edge_name, edge_uid) = relation_node_uid
    Utils.set_transaction(
      tr,
      {uid, edge_name, edge_id},
      relation_node_uid,
      out_edges
    )
  end

  def set_in_edges(tr, relation_node_uid, edge_name, uid, edge_uid, %State{
        in_edges: in_edges
      }) do
    # relation_node_uid, edge_name, uid) = edge_uid
    Utils.set_transaction(
      tr,
      {relation_node_uid, edge_name, uid},
      edge_uid,
      in_edges
    )
  end
end
