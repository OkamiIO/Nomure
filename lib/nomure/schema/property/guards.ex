defmodule Nomure.Schema.Property.Guards do
  defguard is_primitive(value)
           when is_number(value) or is_binary(value) or is_boolean(value) or is_list(value)
end
