defmodule Nomure.Node.State do
  @moduledoc false

  alias FDB.{Transaction, Database}
  alias FDB.Coder.{LittleEndianInteger, Tuple, ByteString, Subspace, Dynamic}
  alias FDB.Directory

  @enforce_keys [:node_name, :props, :props_index, :out_edges, :in_edges]
  defstruct [:node_name, :props, :props_index, :out_edges, :in_edges]

  @type t :: %__MODULE__{
          props: Database.t(),
          props_index: Database.t(),
          out_edges: Database.t(),
          in_edges: Database.t()
        }

  @doc """
  Creates a new state for the given node name and schema definition
  """
  @spec from(FDB.Database.t(), String.t()) :: Nomure.Node.State.t()
  def from(db, node_name) do
    %__MODULE__{
      node_name: node_name,
      props: FDB.Database.set_defaults(db, %{coder: get_props_coder(db, node_name)}),
      props_index: FDB.Database.set_defaults(db, %{coder: get_index_coder(db, node_name)}),
      out_edges: FDB.Database.set_defaults(db, %{coder: get_out_coder(db, node_name)}),
      in_edges: FDB.Database.set_defaults(db, %{coder: get_in_coder(db, node_name)})
    }
  end

  # Creates a properties directory, with the format
  # (node_uid, property_name) = property_value
  defp get_props_coder(db, node_name) do
    props_dir = get_dir(db, node_name, "properties")

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
      ByteString.new()
    )
  end

  # Creates an index directory, with the format
  # (property_name, property_value, node_uid) = ""
  defp get_index_coder(db, node_name) do
    index_dir = get_dir(db, node_name, "indexes")

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
      # dummy_value
      ByteString.new()
    )
  end

  # Creates an out edges directory, with the format
  # (uid, edge_name, edge_uid) = relation_node_uid
  defp get_out_coder(db, node_name) do
    inverse_dir = get_dir(db, node_name, "out")

    Transaction.Coder.new(
      Subspace.new(
        inverse_dir,
        Tuple.new({
          # relation_uid
          get_uid_coder(),
          # edge_name
          ByteString.new(),
          # edge_uid
          get_uid_coder()
        })
      ),
      # relation_node_uid
      get_uid_coder()
    )
  end

  # Creates an in edges directory, with the format
  # (relation_node_uid, edge_name, uid) = edge_uid
  defp get_in_coder(db, node_name) do
    inverse_dir = get_dir(db, node_name, "in")

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
      # edge_uid
      get_uid_coder()
    )
  end

  defp get_uid_coder() do
    # TODO
    # Not sure if 128 bits is the best way to go in this case since by default 64 bits can handle a really big amount of number, but just to be sure
    # we leave it like that
    LittleEndianInteger.new()
  end

  defp get_dir(db, node_name, path_name) do
    Database.transact(db, fn tr ->
      root = Directory.new()
      Directory.create_or_open(root, tr, ["node", node_name, path_name])
    end)
  end
end
