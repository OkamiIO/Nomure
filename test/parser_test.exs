defmodule NomureTest.ParserTest do
  use ExUnit.Case

  alias Nomure.Schema.Plan

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
end
