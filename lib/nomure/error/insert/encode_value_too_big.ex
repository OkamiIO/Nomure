defmodule Nomure.Error.NodeValueTooBig do
  defexception [:message]

  @impl true
  def exception(max_size: max_size, current_size: current_size, compressed?: compressed?) do
    msg = """
    The given value is bigger than max

    Max Size:
    #{inspect(max_size)}

    Buffer Size:
    #{inspect(current_size)}

    Is Compressed?:
    #{inspect(compressed?)}
    """

    %__MODULE__{message: msg}
  end
end
