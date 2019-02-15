defmodule Nomure.Database do
  def start() do
    :ok = FDB.start()

    db =
      FDB.Cluster.create()
      |> FDB.Database.create()

    :persistent_term.put(
      Nomure.TransactionUtils.get_database_state_key(),
      Nomure.Database.State.from(db)
    )
  end

  def get_state() do
    :persistent_term.get(Nomure.TransactionUtils.get_database_state_key())
  end

  def set_schema(schema) when is_binary(schema) do
    :persistent_term.put(:schema, schema |> Jason.decode!())
  end

  def set_schema(schema) when is_map(schema) do
    :persistent_term.put(:schema, schema)
  end

  def get_schema() do
    :persistent_term.get(:schema)
  end

  def get_property_schema(node_name, property_name) do
    get_schema()[node_name][property_name]
  end
end
