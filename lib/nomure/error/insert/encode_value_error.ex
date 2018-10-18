defmodule Nomure.Error.EncodeValueError do
  defexception [:message, :value]

  @impl true
  def exception(value: value) do
    msg = """
    The given value isn't serializable as a foundationdb value

    Value:
    #{inspect(value)}
    """

    %__MODULE__{message: msg, value: value}
  end
end
