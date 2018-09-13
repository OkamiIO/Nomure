defmodule Nomure.Schema.Property.Type do
  @moduledoc """
  Base type for the type descriptions, it describes how the properties are set in FDB and
  set the proper indexes to the property
  """

  @type types ::
          Nomure.Schema.Property.Type.Default.t()
          | Nomure.Schema.Property.Type.String.t()
          | Nomure.Schema.Property.Type.Node.t()

  @callback set_property(types, FDB.Transaction.t(), Nomure.Node.State.t(), tuple()) ::
              FDB.Transaction.t()
  @callback set_index(types, FDB.Transaction.t(), Nomure.Node.State.t(), tuple()) ::
              FDB.Transaction.t()
end
