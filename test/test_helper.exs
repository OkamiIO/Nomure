:ok = FDB.start()

db =
  FDB.Cluster.create()
  |> FDB.Database.create()

Nomure.Node.new(db)

ExUnit.start()
