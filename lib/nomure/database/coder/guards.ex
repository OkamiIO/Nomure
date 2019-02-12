defmodule Nomure.Database.Coder.Guards do
  @string_size Application.get_env(:nomure, :max_string_size_uncompress, 32)

  defguard is_long_string(value) when is_binary(value) and byte_size(value) > @string_size
end
