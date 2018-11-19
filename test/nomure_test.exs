defmodule NomureTest do
  use ExUnit.Case
  doctest Nomure

  alias Nomure.Node
  alias Nomure.Schema.{ParentNode, ChildrenNode}
  alias Nomure.Schema.Query.{ParentQuery, ChildrenQuery}

  alias FDB.{Database, Cluster}

  test "set data" do
    :ok = FDB.start(510)

    db =
      Cluster.create()
      |> Database.create()

    Node.new(db)

    data = %ParentNode{
      node_name: "users",
      node_data: %{
        name: "Sif",
        password: "test",
        email: "test@test.com",
        name@jp: "La biblia de los caidos",
        age: 20,
        gender: true
      },
      node_relationships: %{
        books: [
          %ChildrenNode{
            node_name: "books",
            node_data: %{
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
            edge_data: %{
              since: "20-10-2018"
            }
          }
        ]
      }
    }

    {{node_name, uid}, _relation_uids} = Node.create_node(data)

    node_exist? = Node.node_exist?(uid, node_name)

    lookup_result =
      Database.transact(db, fn tr ->
        %ParentQuery{
          node_name: "users",
          where: [name: "Sif"],
          select: [
            :id
          ]
        }

        # [%{uid: 1}]

        state = Nomure.Database.get_state()

        range = FDB.KeySelectorRange.starts_with({"name", {:unicode_string, "Sif"}})

        FDB.Transaction.get_range(tr, range, %{coder: state.properties_index.coder})
        |> Enum.to_list()
      end)

    book_description =
      Node.query(%ParentQuery{
        node_name: "books",
        where: [id: 2],
        select: [
          :description,
          :author
          # friends in common query! use MapSet.intersection(map_set, map_set)
          # friends: %{where: %{friends: %{intersect: :@friends}}}
        ]
      })

    edge_data =
      Database.transact(db, fn tr ->
        state = Nomure.Database.get_state()

        %ParentQuery{
          node_name: "users",
          where: [id: 1],
          select: [
            books: %ChildrenQuery{
              node_name: "books",
              # where: [id: 2],
              edges: [:since]
            }
          ]
        }

        # {books: [%{since: "date"}]}

        FDB.Transaction.get(tr, {"books", {"users", 1}, {"books", 2}, "since"}, %{
          coder: state.edges.coder
        })
      end)

    assert edge_data == "20-10-2018"

    assert book_description ==
             %{
               author: "Fernando Trujillo Sanz",
               description: """
               El mundo tiene un lado oculto, sobrenatural, que nos susurra, se intuye, pero que pocos perciben.

               La mayoría de las personas no son conscientes de ese lado paranormal... ni de sus riesgos.

               A veces se topan con esos peligros y desesperan, se atemorizan. Pero no todo está perdido...


               Dicen que en Madrid reposa una iglesia antigua. En su interior, frente a una cruz de piedra, se puede alzar una plegaria. Si la fortuna acompaña, aquel que no tiene alma la escuchará. Pero exigirá un elevado precio por sus servicios, que no todos están dispuestos a pagar. Mejor será asegurarse de que de verdad se quiere contar con él antes de recitar la plegaria.
               """
             }

    # TODO normalize result!
    assert lookup_result == [
             {{"name", {{:unicode_string, "Sif"}, {:unicode_string, "users"}, {:integer, 1}}},
              "nil"}
           ]

    assert node_exist? == true
  end

  test "get data" do
    %ParentQuery{
      node_name: "user",
      where: [id: 1],
      select: [
        :name,
        :email,
        :password,
        books: %ChildrenQuery{
          node_name: "book",
          pagination: %{first: 20},
          select: [:name, :description],
          edges: [:since]
        }
      ]
    }

    %{
      name: "Sif",
      email: "bla",
      password: "bla",
      books: %{
        edges: %{
          cursor: 2,
          sinde: "date",
          node: %{name: "La biblia de los caidos", description: "long description"}
        },
        page_info: %{
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: 2,
          endCursor: 2
        }
      }
    }

    assert true == true
  end
end
