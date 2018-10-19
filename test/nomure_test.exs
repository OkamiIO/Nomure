defmodule NomureTest do
  use ExUnit.Case
  doctest Nomure

  alias Nomure.Node
  alias Nomure.Schema.ParentNode

  alias FDB.{Database, Cluster}

  test "node exist?" do
    :ok = FDB.start(510)

    db =
      Cluster.create()
      |> Database.create()

    Node.new(db)

    data = %ParentNode{
      __node_name__: "users",
      __node_data__: %{
        name: "Sif",
        password: "test",
        email: "test@test.com",
        name@jp: "Shifu",
        age: 20,
        gender: true
      }
    }

    {node_name, uid} = Node.create_node(data)

    node_exist? = Node.node_exist?(uid, node_name)

    Database.transact(db, fn tr ->
      [{_key, state} | _] =
        :ets.lookup(:database_state, Nomure.TransactionUtils.get_database_state_key())

      range = FDB.KeySelectorRange.starts_with({"name", {:unicode_string, "Sif"}})

      FDB.Transaction.get_range(tr, range, %{coder: state.properties_index.coder})
      |> Enum.to_list()
      |> IO.inspect()
    end)

    assert node_exist? == true
  end

  test "get data to fdb" do
    # %{
    #   __node_name__: "user",
    #   name: nil,
    #   email: nil,
    #   password: nil,
    #   books: %{
    #     page_info: nil,
    #     aggregate: nil,
    #     edges: %{
    #       __node_name__: "book",
    #       __function__: %{
    #         where: %{
    #           edge_score: "10",
    #           node_release_date: "2018"
    #         }
    #       },
    #       score: nil,
    #       node: %{
    #         name: [lang: :es],
    #         release_date: nil,
    #         lovers_count: nil
    #       }
    #     }
    #   }
    # }

    assert true == true
  end

  test "set data to fdb" do
    # data = %{
    #   __node_name__: "user",
    #   __node_data__: %{
    #     name: "Sif",
    #     email: "example@example.com",
    #     password: "super_strong",
    #     books: [
    #       %{
    #         __node_name__: "book",
    #         __edge_data__: %{score: "10"},
    #         __node_data__: %{
    #           name: "La biblia de los caidos",
    #           # provisional just for reference
    #           release_date: "2018"
    #           # can't set lovers_count since is count property
    #         }
    #       }
    #     ]
    #   }
    # }

    # data.__node_data__
    # |> Enum.filter(fn {_key, value} -> !is_list(value) end)
    # |> Map.new()

    assert true == true
  end
end
