defmodule TestBla do
  defstruct [:instruction, :on_sucess, :on_fail]

  # Eg. in query data
  %{
    where: %{
      OR: [
        %{
          description: "description"
        },
        %{
          description: nil
        }
      ],
      createdAt_gt: "2017",
      createdAt_lt: "2019"
    }
  }

  # out data for process
  # it must share some data, this data is an MapSet of uids! that is trans
  %{
    # evaluate both
    instruction: %{createdAt_gt: "2017", createdAt_lt: "2019"},
    on_sucess: %{
      instruction: %{description: "description"},
      on_sucess: :success,
      on_fail: %{
        instruction: %{description: nil},
        on_sucess: :success,
        on_fail: :fail
      }
    },
    on_fail: :fail
  }
end
