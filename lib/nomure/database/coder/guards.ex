defmodule Nomure.Database.Coder.Guards do
  defguard is_byte(value) when is_integer(value) and value >= -128 and value <= 127

  defguard is_short(value) when is_integer(value) and value >= -32768 and value <= 32767

  defguard is_int(value)
           when is_integer(value) and value >= -2_147_483_648 and value <= 2_147_483_647

  defguard is_long(value)
           when is_integer(value) and value >= -9_223_372_036_854_775_808 and
                  value <= 9_223_372_036_854_775_807

  defguard is_long_string(value) when is_binary(value) and byte_size(value) > 16
end
