defmodule Nomure.Schema.Plan do
  @moduledoc """
  Describes a behaviour tree that is generated from the `where` requests

  Example:

    In data:
      ```
      %{
        where: %{
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
        }
      }
      ```

    Out data:
      ```
         %Plan{
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
      ```
  """
  @enforce_keys [:instruction, :on_success, :on_fail]
  defstruct [:instruction, :on_success, :on_fail]
end
