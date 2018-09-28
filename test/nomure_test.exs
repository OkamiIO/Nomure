defmodule NomureTest do
  use ExUnit.Case
  doctest Nomure

  test "greets the world" do
    assert Nomure.hello() == :world
  end

  test "get data to fdb" do
    %{
      __node_name__: "user",
      name: nil,
      email: nil,
      password: nil,
      books: %{
        page_info: nil,
        aggregate: nil,
        edges: %{
          __node_name__: "book",
          __function__: %{
            where: %{
              edge_score: "10",
              node_release_date: "2018"
            }
          },
          score: nil,
          node: %{
            name: [lang: :es],
            release_date: nil,
            lovers_count: nil
          }
        }
      }
    }

    assert true == true
  end

  test "set data to fdb" do
    data = %{
      __node_name__: "user",
      __node_data__: %{
        name: "Sif",
        email: "example@example.com",
        password: "super_strong",
        books: [
          %{
            __node_name__: "book",
            __edge_data__: %{score: "10"},
            __node_data__: %{
              name: "La biblia de los caidos",
              # provisional just for reference
              release_date: "2018"
              # can't set lovers_count since is count property
            }
          }
        ]
      }
    }

    data.__node_data__
    |> Enum.filter(fn {_key, value} -> !is_list(value) end)
    |> Map.new()

    assert true == true
  end
end
