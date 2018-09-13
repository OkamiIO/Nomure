defmodule Nomure.Schema.Property.Type.String do
  @moduledoc """
  String type, describes property serialization

  Not indexes implemented yet
  """
  @behaviour Nomure.Schema.Property.Type

  alias Nomure.TransactionUtils
  alias Nomure.Node.State

  @enforce_keys [:name]
  defstruct [:name, indexes: []]

  @type t :: %__MODULE__{
          name: String.t()
        }

  @impl true
  def set_property(%__MODULE__{name: property_name}, tr, %State{props: props_dir}, {uid, value}) do
    # TODO I18N serialize, maybe create a I18NString type
    # basically add the language prefix to the end of the string and index the string
    TransactionUtils.set_transaction(
      tr,
      {uid, property_name},
      value,
      props_dir
    )
  end

  @impl true
  def set_index(%__MODULE__{}, tr, _, _) do
    tr
  end
end
