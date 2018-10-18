defmodule Nomure.Error.UnknownNodeError do
  defexception [:message, :edge_name, :value, :node_name]

  @impl true
  def exception(edge_name: prop_name, value: value, node_name: node_name) do
    msg = """
    The given uid does not exist

    Edge Name:
    #{inspect(prop_name)}

    Given uid value:
    {#{inspect(node_name)} ,#{inspect(value)}}
    """

    %__MODULE__{message: msg, edge_name: prop_name, value: value, node_name: node_name}
  end
end
