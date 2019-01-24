defmodule Nomure.Database.State do
  @enforce_keys [
    :db,
    :properties,
    :properties_index,
    :out_nodes,
    :inverse_nodes,
    :edges
  ]
  defstruct [
    :db,
    :properties,
    :properties_index,
    :out_nodes,
    :inverse_nodes,
    :edges
  ]

  alias FDB.{Transaction, Database}

  alias FDB.Coder.{
    Integer,
    Tuple,
    ByteString,
    Subspace,
    Dynamic,
    NestedTuple
  }

  alias FDB.Directory

  alias Nomure.Database.Coder.GraphValue

  @property_key "p"
  @property_index_key "pi"
  @out_nodes_key "o"
  @in_nodes_key "i"
  @edges_key "e"

  @type t :: %__MODULE__{
          db: Database.t(),
          properties: Database.t(),
          properties_index: Database.t(),
          out_nodes: Database.t(),
          inverse_nodes: Database.t(),
          edges: Database.t()
        }

  def from(db) do
    %__MODULE__{
      db: db,
      properties: FDB.Database.set_defaults(db, %{coder: get_properties_coder(db)}),
      properties_index: FDB.Database.set_defaults(db, %{coder: get_properties_index_coder(db)}),
      out_nodes: FDB.Database.set_defaults(db, %{coder: get_out_nodes_coder(db)}),
      inverse_nodes: FDB.Database.set_defaults(db, %{coder: get_inverse_nodes_coder(db)}),
      edges: FDB.Database.set_defaults(db, %{coder: get_edges_coder(db)})
    }
  end

  # Creates a properties directory, with the format
  # (uid, property_name) = property_value
  defp get_properties_coder(db) do
    props_dir = get_dir(db, @property_key)

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
    index_dir = get_dir(db, @property_index_key)

    Transaction.Coder.new(
      Subspace.new(
        index_dir,
        Tuple.new({
          # node_name
          ByteString.new(),
          # property_name
          ByteString.new(),
          # {property_value, node_uid}
          Dynamic.new()
        })
      ),
      # dummy_value, nil
      GraphValue.new()
    )
  end

  # Creates an out edges directory, with the format
  # (uid, edge_name, relation_node_uid)
  defp get_out_nodes_coder(db) do
    inverse_dir = get_dir(db, @out_nodes_key)

    Transaction.Coder.new(
      Subspace.new(
        inverse_dir,
        Tuple.new({
          # node_uid
          get_uid_coder(),
          # edge_name
          ByteString.new(),
          # relation_uid
          get_uid_coder()
        })
      ),
      # dummy_value, nil
      GraphValue.new()
    )
  end

  # Creates an in edges directory, with the format
  # (relation_node_uid, edge_name, uid)
  defp get_inverse_nodes_coder(db) do
    inverse_dir = get_dir(db, @in_nodes_key)

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
      GraphValue.new()
    )
  end

  defp get_edges_coder(db) do
    inverse_dir = get_dir(db, @edges_key)

    Transaction.Coder.new(
      Subspace.new(
        inverse_dir,
        Tuple.new({
          # edge_name
          ByteString.new(),
          # node_uid
          get_uid_coder(),
          # relation_uid
          get_uid_coder(),
          # edge_property_name
          ByteString.new()
        })
      ),
      # edge property value
      GraphValue.new()
    )
  end

  # defines the uid coder
  #
  # params{node_name}: string
  # params{uid}: integer
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
