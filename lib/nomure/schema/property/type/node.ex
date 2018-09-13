defmodule Nomure.Schema.Property.Type.Node do
  @behaviour Nomure.Schema.Property.Type

  alias Nomure.TransactionUtils
  alias Nomure.Node.{State, Impl}

  defstruct [:name, edges: []]

  @impl true
  def set_property(
        %__MODULE__{name: property_name},
        tr,
        %State{node_name: main_node_name, out_edges: edges_dir} = state,
        {uid, %{uid: relationship_uid, node_name: node_name}}
      )
      when node_name == main_node_name do
    # we can't call the same Genserver we are running the operation!
    case Impl.node_exist?(tr, relationship_uid, state) do
      {:ok, tr, false} ->
        # TODO reset transaction and raise exception to block any other operation
        FDB.Transaction.cancel(tr)

      _ ->
        # TODO get edge uid
        edge_uid = <<0x01>>
        # serialize data
        TransactionUtils.set_transaction(
          tr,
          {uid, property_name, edge_uid},
          relationship_uid,
          edges_dir
        )
    end
  end

  def set_property(
        %__MODULE__{},
        tr,
        %State{},
        {_uid, %{uid: relationship_uid, node_name: node_name}}
      ) do
    case Nomure.Node.node_uid_present?(tr, relationship_uid, node_name) do
      {:ok, tr, false} ->
        # TODO reset transaction and raise exception to block any other operation
        FDB.Transaction.cancel(tr)

      _ ->
        # get vertex uid
        # serialize data
        tr
    end
  end

  def set_property(%__MODULE__{}, tr, %State{}, {_uid, %{} = _data}) do
    # check if data is a nodeUI or a map structure
    # if uid check it exist and set
    # if map call Node.create_node with the actual transaction and the data to get the relation_ship_uid
    # set the vertex data and get the vertex uid

    # serialize the data
    tr
  end

  @impl true
  def set_index(%__MODULE__{}, tr, %State{}, {_uid, _data}) do
    tr
  end
end
