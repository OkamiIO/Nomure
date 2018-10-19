defmodule Nomure.Database.State do
  @enforce_keys [
    :db,
    :serialize_as_blob,
    :properties,
    :properties_index,
    :out_nodes,
    :inverse_nodes
  ]
  defstruct [:db, :serialize_as_blob, :properties, :properties_index, :out_nodes, :inverse_nodes]

  @serialize_as_blob Application.get_env(:nomure, :serialize_as_blob)

  alias FDB.{Transaction, Database}

  alias FDB.Coder.{
    Integer,
    Tuple,
    ByteString,
    Subspace,
    Dynamic,
    NestedTuple,
    Nullable,
    Identity
  }

  alias FDB.Directory

  alias Nomure.Database.Coder.GraphValue

  @type t :: %__MODULE__{
          db: Database.t(),
          serialize_as_blob: boolean(),
          properties: Database.t(),
          properties_index: Database.t(),
          out_nodes: Database.t(),
          inverse_nodes: Database.t()
        }

  def from(db, serialize_as_blob \\ @serialize_as_blob) do
    %__MODULE__{
      db: db,
      serialize_as_blob: serialize_as_blob,
      properties:
        FDB.Database.set_defaults(db, %{coder: get_properties_coder(db, serialize_as_blob)}),
      properties_index: FDB.Database.set_defaults(db, %{coder: get_properties_index_coder(db)}),
      out_nodes: FDB.Database.set_defaults(db, %{coder: get_out_nodes_coder(db)}),
      inverse_nodes: FDB.Database.set_defaults(db, %{coder: get_inverse_nodes_coder(db)})
    }
  end

  # Creates a properties directory, with the format
  # (uid, property_name) = property_value
  defp get_properties_coder(db, serialize_as_blob) do
    props_dir = get_dir(db, "p")

    do_get_properties_coder(props_dir, serialize_as_blob)
  end

  defp do_get_properties_coder(props_dir, true) do
    Transaction.Coder.new(
      Subspace.new(
        props_dir,
        Tuple.new({
          # node_uid
          get_uid_coder()
        })
      ),
      # node_properties
      Identity.new()
    )
  end

  defp do_get_properties_coder(props_dir, false) do
    Transaction.Coder.new(
      Subspace.new(
        props_dir,
        Tuple.new({
          # node_uid
          get_uid_coder(),
          # property_name
          ByteString.new()
        })
      ),
      # property_value
      GraphValue.new()
    )
  end

  # Creates an index directory, with the format
  # (property_name, property_value, node_uid)
  defp get_properties_index_coder(db) do
    index_dir = get_dir(db, "pi")

    Transaction.Coder.new(
      Subspace.new(
        index_dir,
        Tuple.new({
          # property_name
          ByteString.new(),
          # property_value
          Dynamic.new(),
          # node_uid
          get_uid_coder()
        })
      ),
      # dummy_value, nil
      GraphValue.new()
    )
  end

  # Creates an out edges directory, with the format
  # (uid, edge_name, relation_node_uid)
  defp get_out_nodes_coder(db) do
    inverse_dir = get_dir(db, "o")

    Transaction.Coder.new(
      Subspace.new(
        inverse_dir,
        Tuple.new({
          # relation_uid
          get_uid_coder(),
          # edge_name
          ByteString.new(),
          # relation_node_uid
          get_uid_coder()
        })
      ),
      # dummy_value, nil
      Nullable.new(Identity.new())
    )
  end

  # Creates an in edges directory, with the format
  # (relation_node_uid, edge_name, uid)
  defp get_inverse_nodes_coder(db) do
    inverse_dir = get_dir(db, "in")

    Transaction.Coder.new(
      Subspace.new(
        inverse_dir,
        Tuple.new({
          # relation_uid
          get_uid_coder(),
          # edge_name
          ByteString.new(),
          # node_uid
          get_uid_coder()
        })
      ),
      # dummy_value, nil
      Nullable.new(Identity.new())
    )
  end

  # defines the uid coder
  #
  # params{node_name}: string
  # params{uid}: 64 bits little endian integer
  #
  # (node_name, uid)
  defp get_uid_coder() do
    NestedTuple.new({ByteString.new(), Integer.new()})
  end

  defp get_dir(db, path_name) do
    Database.transact(db, fn tr ->
      root = Directory.new()
      Directory.create_or_open(root, tr, ["node", path_name])
    end)
  end
end
