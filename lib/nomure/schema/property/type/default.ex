defmodule Nomure.Schema.Property.Type.Default do
  @moduledoc """
  Describes a basic primite type serialization, this applies to `integer`, `float`, `boolean`.

  They all share the same way of serializing in FDB

  By default the property type is indexed
  """
  @behaviour Nomure.Schema.Property.Type

  alias Nomure.TransactionUtils
  alias Nomure.Node.State

  @enforce_keys [:name]
  defstruct [:name, is_indexed: true]

  @type t :: %__MODULE__{
          name: String.t(),
          is_indexed: boolean
        }

  @impl true
  def set_property(%__MODULE__{name: property_name}, tr, %State{props: props_dir}, {uid, value}) do
    TransactionUtils.set_transaction(
      tr,
      {uid, property_name},
      value,
      props_dir
    )
  end

  @impl true
  def set_index(%__MODULE__{is_indexed: false}, tr, _, _) do
    tr
  end

  def set_index(
        %__MODULE__{name: property_name, is_indexed: true},
        tr,
        %State{props_index: props_index},
        {uid, value}
      ) do
    TransactionUtils.set_transaction(
      tr,
      {property_name, value, uid},
      "",
      props_index
    )
  end
end
