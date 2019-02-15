defmodule NomureTest do
  use ExUnit.Case
  doctest Nomure

  alias Nomure.Node
  alias Nomure.Schema.{ParentNode, ChildrenNode}
  alias Nomure.Schema.Query.{ParentQuery, ChildrenQuery, UniqueQuery}

  @schema %{
    "users" => %{
      "status" => %{
        "type" => "enum",
        "index" => true,
        "values" => %{
          "working" => 0,
          "resting" => 1,
          "complaining" => 2
        }
      },
      "name" => %{
        "type" => "string",
        "index" => ["exact"]
      },
      "password" => %{
        "type" => "string"
      },
      "email" => %{
        "type" => "string",
        "index" => ["unique"]
      },
      "name@jp" => %{
        "type" => "string",
        "index" => ["exact"]
      },
      "magic_number" => %{
        "type" => "integer",
        "index" => true
      },
      "age" => %{
        "type" => "integer",
        "index" => true
      },
      "gender" => %{
        "type" => "boolean"
      },
      "a_list" => %{
        "type" => "list"
      },
      "books" => %{
        "type" => "node_list",
        "node_type" => "books"
      }
    },
    "books" => %{
      "name" => %{
        "type" => "string",
        "index" => "fulltext"
      },
      "author" => %{
        "type" => "string"
      },
      "description" => %{
        "type" => "string"
      },
      "release_date" => %{
        "type" => "date",
        "index" => true
      },
      "datetime" => %{
        "type" => "datetime",
        "index" => true
      },
      "magic_number" => %{
        "type" => "integer",
        "index" => true
      }
    }
  }

  setup_all do
    :os.cmd(~S"fdbcli --exec \"writemode on; clearrange \x00 \xff;\"" |> String.to_charlist())

    Nomure.Database.set_schema(@schema)

    date = DateTime.utc_now()

    data = %ParentNode{
      node_name: "users",
      node_data: %{
        name: "Sif",
        password: "test",
        email: "test@test.com",
        name@jp: "シフ",
        magic_number: 45,
        age: 20,
        gender: true,
        a_list: [5, 5, 8, 4, 3, 4],
        status: "working"
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
              release_date: Date.new(2015, 10, 1) |> elem(1),
              datetime: date,
              magic_number: 46
            },
            edge_data: %{
              since: "20-10-2018"
            }
          }
        ]
      }
    }

    {{node_name, uid}, %{books: [{_, relation_uid}]}} = Node.create_node(data)

    {:ok, %{parent_uid: {node_name, uid}, child_uid: relation_uid, date: date}}
  end

  test "node exist?", %{parent_uid: {node_name, uid}} do
    assert Node.node_exist?(uid, node_name)
  end

  test "query all properties", %{parent_uid: {_node_name, uid}} do
    assert Node.query(%ParentQuery{
             node_name: "users",
             where: %{
               OR: [
                 %{magic_number_gte: 40, magic_number_lte: 50},
                 %{name: "Sif"}
               ]
             },
             select: []
           }) == [
             %{
               __node_name__: "users",
               a_list: [5, 5, 8, 4, 3, 4],
               age: 20,
               email: "test@test.com",
               gender: true,
               id: uid,
               magic_number: 45,
               name: "Sif",
               name@jp: "シフ",
               password: "test",
               status: 0
             }
           ]
  end

  test "between where query", %{parent_uid: {_, uid}} do
    assert [%{age: 20, email: "test@test.com", id: uid, name@jp: "シフ"}] ==
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
  end

  test "where enum", _ do
    assert [%{status: "working"}] ==
             Node.query(%ParentQuery{
               node_name: "users",
               where: %{
                 status: "working"
               },
               select: [
                 :status
               ]
             })
  end

  test "unique id query", %{child_uid: relation_uid} do
    assert %{
             author: "Fernando Trujillo Sanz",
             description: """
             El mundo tiene un lado oculto, sobrenatural, que nos susurra, se intuye, pero que pocos perciben.

             La mayoría de las personas no son conscientes de ese lado paranormal... ni de sus riesgos.

             A veces se topan con esos peligros y desesperan, se atemorizan. Pero no todo está perdido...

             Dicen que en Madrid reposa una iglesia antigua. En su interior, frente a una cruz de piedra, se puede alzar una plegaria. Si la fortuna acompaña, aquel que no tiene alma la escuchará. Pero exigirá un elevado precio por sus servicios, que no todos están dispuestos a pagar. Mejor será asegurarse de que de verdad se quiere contar con él antes de recitar la plegaria.
             """
           } ==
             Node.query(%UniqueQuery{
               node_name: "books",
               identifier: [id: relation_uid],
               select: [
                 :description,
                 :author
               ]
             })
  end

  test "unique index query", _ do
    assert %{name@jp: "シフ"} ==
             Node.query(%UniqueQuery{
               node_name: "users",
               identifier: [email: "test@test.com"],
               select: [
                 :name@jp
               ]
             })
  end

  test "where date/time", %{date: date} do
    book_by_date =
      Node.query(%ParentQuery{
        node_name: "books",
        where: %{release_date_gte: "2014"},
        select: [
          :author,
          :release_date
        ]
      })

    book_by_datetime =
      Node.query(%ParentQuery{
        node_name: "books",
        where: %{datetime_gte: "#{date.year}-01"},
        select: [
          :author,
          :release_date,
          :datetime
        ]
      })

    assert book_by_datetime == [
             %{
               author: "Fernando Trujillo Sanz",
               datetime: date,
               release_date: ~D[2015-10-01]
             }
           ]

    assert book_by_date == [%{author: "Fernando Trujillo Sanz", release_date: ~D[2015-10-01]}]
  end

  test "complex query", %{parent_uid: {_, uid}, child_uid: relation_uid, date: date} do
    relation_ship_query =
      Node.query(%UniqueQuery{
        node_name: "users",
        identifier: [id: uid],
        select: [
          :name,
          :magic_number,
          :a_list,
          books: %ChildrenQuery{
            node_name: "books",
            where: %{datetime_gte: "#{date.year}-01"},
            select: [
              :description,
              :author,
              :release_date
            ],
            edges: [:since]
          }
        ]
      })

    assert relation_ship_query == %{
             a_list: [5, 5, 8, 4, 3, 4],
             magic_number: 45,
             name: "Sif",
             books: %{
               edges: [
                 %{
                   cursor: relation_uid,
                   node: %{
                     author: "Fernando Trujillo Sanz",
                     description: """
                     El mundo tiene un lado oculto, sobrenatural, que nos susurra, se intuye, pero que pocos perciben.

                     La mayoría de las personas no son conscientes de ese lado paranormal... ni de sus riesgos.

                     A veces se topan con esos peligros y desesperan, se atemorizan. Pero no todo está perdido...

                     Dicen que en Madrid reposa una iglesia antigua. En su interior, frente a una cruz de piedra, se puede alzar una plegaria. Si la fortuna acompaña, aquel que no tiene alma la escuchará. Pero exigirá un elevado precio por sus servicios, que no todos están dispuestos a pagar. Mejor será asegurarse de que de verdad se quiere contar con él antes de recitar la plegaria.
                     """,
                     release_date: Date.new(2015, 10, 1) |> elem(1)
                   },
                   since: "20-10-2018"
                 }
               ]
             }
           }
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
        edges: [
          %{
            cursor: 2,
            since: "date",
            node: %{name: "La biblia de los caidos", description: "long description"}
          }
        ],
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
