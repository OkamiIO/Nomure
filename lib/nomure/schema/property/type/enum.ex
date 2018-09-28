# defmodule Nomure.Schema.Property.Type.Enum do
#   @moduledoc """
#   Same as String type, but it is serialized and indexed
#   """
#   @behaviour Nomure.Schema.Property.Type

#   alias Nomure.TransactionUtils
#   alias Nomure.Node.State

#   @enforce_keys [:name]
#   defstruct [:name, indexes: []]

#   @type t :: %__MODULE__{
#           name: String.t()
#         }

#   @impl true
#   def set_property(%__MODULE__{name: property_name}, tr, %State{props: props_dir}, {uid, value}) do
#     TransactionUtils.set_transaction(
#       tr,
#       {uid, property_name},
#       value,
#       props_dir
#     )
#   end

#   @impl true
#   def set_index(
#         %__MODULE__{name: property_name},
#         tr,
#         %State{props_index: props_index},
#         {uid, value}
#       ) do
#     TransactionUtils.set_transaction(
#       tr,
#       {property_name, value, uid},
#       "",
#       props_index
#     )
#   end
# end
