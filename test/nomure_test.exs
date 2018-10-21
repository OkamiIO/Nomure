defmodule NomureTest do
  use ExUnit.Case
  doctest Nomure

  alias Nomure.Node
  alias Nomure.Schema.{ParentNode, ChildrenNode}

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
        name@jp: "La biblia de los caidos",
        age: 20,
        gender: true
      },
      __node_relationships__: %{
        books: [
          %ChildrenNode{
            __node_name__: "books",
            __node_data__: %{
              name: "La biblia de los caidos",
              author: "Fernando Trujillo Sanz",
              description: """
              El mundo tiene un lado oculto, sobrenatural, que nos susurra, se intuye, pero que pocos perciben.

              La mayoría de las personas no son conscientes de ese lado paranormal... ni de sus riesgos.

              A veces se topan con esos peligros y desesperan, se atemorizan. Pero no todo está perdido...


              Dicen que en Madrid reposa una iglesia antigua. En su interior, frente a una cruz de piedra, se puede alzar una plegaria. Si la fortuna acompaña, aquel que no tiene alma la escuchará. Pero exigirá un elevado precio por sus servicios, que no todos están dispuestos a pagar. Mejor será asegurarse de que de verdad se quiere contar con él antes de recitar la plegaria.
              """,
              # TODO dates!
              release_date: "octubre de 2015"
            },
            __edge_data__: %{
              since: "20-10-2018"
            }
          }
        ]
      }
    }

    {{node_name, uid}, relation_uids} = Node.create_node(data)

    node_exist? = Node.node_exist?(uid, node_name)

    lookup_result =
      Database.transact(db, fn tr ->
        [{_key, state} | _] =
          :ets.lookup(:database_state, Nomure.TransactionUtils.get_database_state_key())

        range = FDB.KeySelectorRange.starts_with({"name", {:unicode_string, "Sif"}})

        FDB.Transaction.get_range(tr, range, %{coder: state.properties_index.coder})
        |> Enum.to_list()
      end)

    book_description =
      Database.transact(db, fn tr ->
        [{_key, state} | _] =
          :ets.lookup(:database_state, Nomure.TransactionUtils.get_database_state_key())

        FDB.Transaction.get(tr, {{"books", 2}, "description"}, %{coder: state.properties.coder})
      end)

    edge_data =
      Database.transact(db, fn tr ->
        [{_key, state} | _] =
          :ets.lookup(:database_state, Nomure.TransactionUtils.get_database_state_key())

        FDB.Transaction.get(tr, {"books", {"users", 1}, {"books", 2}, "since"}, %{
          coder: state.edges.coder
        })
      end)

    assert edge_data == "20-10-2018"

    assert book_description ==
             """
             El mundo tiene un lado oculto, sobrenatural, que nos susurra, se intuye, pero que pocos perciben.

             La mayoría de las personas no son conscientes de ese lado paranormal... ni de sus riesgos.

             A veces se topan con esos peligros y desesperan, se atemorizan. Pero no todo está perdido...


             Dicen que en Madrid reposa una iglesia antigua. En su interior, frente a una cruz de piedra, se puede alzar una plegaria. Si la fortuna acompaña, aquel que no tiene alma la escuchará. Pero exigirá un elevado precio por sus servicios, que no todos están dispuestos a pagar. Mejor será asegurarse de que de verdad se quiere contar con él antes de recitar la plegaria.
             """

    # TODO normalize result!
    assert lookup_result == [
             {{"name", {{:unicode_string, "Sif"}, {:unicode_string, "users"}, {:integer, 1}}},
              "nil"}
           ]

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
