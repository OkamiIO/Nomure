defmodule Nomure.Node.Impl do
  import FDB.Option

  alias Nomure.Node.State
  alias Nomure.TransactionUtils, as: Utils
  alias Nomure.Database.State, as: DatabaseState
  alias FDB.Transaction
  alias Nomure.Schema.{ParentNode, ChildrenNode}

  @type uid :: non_neg_integer()
  @type property_name :: String.t()
  @type value :: any()

  def set_data(
        tr,
        data,
        %State{
          database_state: %DatabaseState{serialize_as_blob: serialize_as_blob}
        } = state
      )
      when is_map(data) do
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

    uid = get_node_uid(tr)

    do_set_data(tr, uid, data, state.database_state, serialize_as_blob)
  end

  def node_exist?(tr, uid, %State{database_state: %DatabaseState{properties: props_dir}}) do
    {:ok, tr, result} = Utils.get_transaction(tr, {uid}, props_dir)

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
    # TODO do not index if value is nil
    property_type.set_index(property, tr, state, {uid, value})
  end

  def set_out_edges(tr, uid, edge_name, edge_id, relation_node_uid, %State{
        database_state: %DatabaseState{out_nodes: out_edges}
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
        database_state: %DatabaseState{inverse_nodes: in_edges}
      }) do
    # relation_node_uid, edge_name, uid) = edge_uid
    Utils.set_transaction(
      tr,
      {relation_node_uid, edge_name, uid},
      edge_uid,
      in_edges
    )
  end

  defp get_node_uid(tr) do
    Transaction.atomic_op(
      tr,
      "node:counter",
      mutation_type_add(),
      <<1::little-integer-unsigned-size(64)>>
    )

    <<counter::little-integer-unsigned-size(64)>> = Transaction.get(tr, "node:counter")
    counter
  end

  defp do_set_data(
         tr,
         uid,
         %ParentNode{__node_name__: parent_node_name, __node_data__: node_data},
         %State{
           node_name: node_name,
           database_state: %DatabaseState{properties: properties}
         },
         true
       ) do
    insert_properties =
      node_data
      |> Enum.filter(fn {_key, value} -> !is_list(value) end)
      |> Enum.into(%{})

    node_properties =
      node_data
      |> Enum.filter(fn
        {_key, %ChildrenNode{}} -> true
        {_key, _value} -> false
      end)

    Utils.set_transaction(
      tr,
      {uid},
      insert_properties,
      properties
    )

    {:ok, tr, uid}
  end

  defp do_set_data(_tr, _uid, _data, _state, false) do
    # TODO get the datetypes based on the given data (type inference)
    raise "Properties serializer not implemented, soon"
  end
end
