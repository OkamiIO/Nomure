defmodule Nomure.Error.NodeValueError do
  defexception [:message, :relation_uid, :edge_name]

  @impl true
  def exception(relation_uid: relation_uid, edge_name: edge_name) do
    msg = """
    The given relation uid does not exist in the database

    Relation Uid:
    #{inspect(relation_uid)}

    Edge name:
    #{inspect(edge_name)}
    """

    %__MODULE__{message: msg, relation_uid: relation_uid, edge_name: edge_name}
  end
end
