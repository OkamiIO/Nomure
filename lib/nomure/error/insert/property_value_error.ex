defmodule Nomure.Error.PropertyValueError do
  defexception [:message, :property_name, :value]

  @impl true
  def exception(property_name: prop_name, value: value) do
    msg = """
    The given property value isn't a valid primitive

    Property Name:
    #{inspect(prop_name)}

    Property Value:
    #{inspect(value)}
    """

    %__MODULE__{message: msg, property_name: prop_name, value: value}
  end
end
