defmodule NomureTest do
  use ExUnit.Case
  doctest Nomure

  alias Nomure.Node
  alias Nomure.Schema.{ParentNode, ChildrenNode}
  alias Nomure.Schema.Query.{ParentQuery, ChildrenQuery, UniqueQuery}
  alias Nomure.Schema.Plan
  alias Nomure.TransactionUtils

  alias FDB.{Database, Cluster}

  test "parser test" do
    parsed =
      Nomure.Schema.Query.Plan.Parser.parse(%{
        OR: [
          %{
            description: "description",
            OR: [
              %{
                test: "hmmm"
              },
              %{
                test: nil
              }
            ]
          },
          %{
            description: nil,
            date: "2018"
          }
        ],
        date: "bla",
        createdAt: "2016",
        createdAt_gt: "2017",
        createdAt_lt: "2019"
      })

    result = %Plan{
      instruction: {"createdAt", %{"eq" => "2016", "gt" => "2017", "lt" => "2019"}},
      on_fail: :fail,
      on_success: %Nomure.Schema.Plan{
        instruction: {"date", "bla"},
        on_fail: %Nomure.Schema.Plan{
          instruction: {"description", "description"},
          on_fail: %Nomure.Schema.Plan{
            instruction: {"test", "hmmm"},
            on_fail: %Nomure.Schema.Plan{
              instruction: {"test", nil},
              on_fail: %Nomure.Schema.Plan{
                instruction: {"date", "2018"},
                on_fail: :fail,
                on_success: %Nomure.Schema.Plan{
                  instruction: {"description", nil},
                  on_fail: :fail,
                  on_success: :success
                }
              },
              on_success: :success
            },
            on_success: :success
          },
          on_success: :success
        },
        on_success: :success
      }
    }

    or_parse =
      Nomure.Schema.Query.Plan.Parser.parse(%{
        OR: [
          %{magic_number_gte: 46},
          %{name: "Sif"}
        ]
      })

    or_result = %Plan{
      instruction: {"magic_number", %{"gte" => 46}},
      on_fail: %Plan{
        instruction: {"name", "Sif"},
        on_fail: :fail,
        on_success: :success
      },
      on_success: :success
    }

    assert parsed == result
    assert or_parse == or_result
  end

  test "set data" do
    :os.cmd(~S"fdbcli --exec \"writemode on; clearrange \x00 \xff;\"" |> String.to_charlist())

    data = %ParentNode{
      node_name: "users",
      node_data: %{
        name: "Sif",
        password: "test",
        email: "test@test.com",
        name@jp: "シフ",
        magic_number: 45,
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
              release_date: "octubre de 2015",
              magic_number: 46
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
      Node.query(%ParentQuery{
        node_name: "users",
        where: %{
          OR: [
            %{magic_number_gte: 40, magic_number_lte: 50},
            %{name: "Sif"}
          ]
        },
        select: [
          :id,
          :age,
          :email,
          :name@jp
        ]
      })

    book_data =
      Node.query(%UniqueQuery{
        node_name: "books",
        identifier: [id: 2],
        select: [
          :description,
          :author
          # friends in common query! use MapSet.intersection(map_set, map_set)
          # friends: %{where: %{friends: %{intersect: :@friends}}}
        ]
      })

    edge_data =
      TransactionUtils.transact(fn tr, state ->
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

    assert book_data ==
             %{
               author: "Fernando Trujillo Sanz",
               description: """
               El mundo tiene un lado oculto, sobrenatural, que nos susurra, se intuye, pero que pocos perciben.

               La mayoría de las personas no son conscientes de ese lado paranormal... ni de sus riesgos.

               A veces se topan con esos peligros y desesperan, se atemorizan. Pero no todo está perdido...


               Dicen que en Madrid reposa una iglesia antigua. En su interior, frente a una cruz de piedra, se puede alzar una plegaria. Si la fortuna acompaña, aquel que no tiene alma la escuchará. Pero exigirá un elevado precio por sus servicios, que no todos están dispuestos a pagar. Mejor será asegurarse de que de verdad se quiere contar con él antes de recitar la plegaria.
               """
             }

    assert lookup_result == [%{age: 20, email: "test@test.com", id: 1, name@jp: "シフ"}]

    assert node_exist?
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
