defmodule Nomure.Schema.Query.Plan.Parser do
  @moduledoc """
  Parse the `where` given query into a behaviour tree like structure
  """
  alias Nomure.Schema.Plan

  @instructions [
    "_gt",
    "_gte",
    "_lt",
    "_lte",
    "_eq",
    "_intersect"
  ]

  def parse(statement) do
    sorted_keys = get_clean_key_names(statement)

    get_instructions(sorted_keys, statement)
  end

  def get_instructions(instruction, statements, fail_instruction \\ :fail)

  def get_instructions(["OR"], statements, fail_instruction) do
    statements = for {key, val} <- statements, into: %{}, do: {to_string(key), val}
    resolve_or_instruction(Map.get(statements, "OR"), fail_instruction)
  end

  def get_instructions([name | new_keys], statements, fail_instruction) do
    statements = for {key, val} <- statements, into: %{}, do: {to_string(key), val}

    similar_instructions =
      Enum.filter(statements, fn {x, _} -> String.replace(x, @instructions, "") == name end)
      |> Map.new()
      |> Map.keys()

    instructions =
      Enum.map(similar_instructions, fn
        ^name -> Map.get(statements, name)
        x -> {x |> String.replace(name <> "_", ""), Map.get(statements, x)}
      end)

    instructions =
      if Enum.any?(instructions, fn x -> is_tuple(x) end) do
        # if atribute has the property name then is an `eq` instruction
        instructions
        |> Enum.map(fn
          {x, v} -> {x, v}
          value -> {"eq", value}
        end)
        |> Map.new()
      else
        instructions
        |> List.first()
      end

    instruc_values = {name, instructions}

    get_instruction(new_keys, instruc_values, fail_instruction, statements)
  end

  # No more instructions, if sucess all right, if fail all operation fails
  def get_instruction([], instruc_values, fail_instruction, _statements) do
    %Plan{
      instruction: instruc_values,
      on_success: :success,
      on_fail: fail_instruction
    }
  end

  # OR instruction, decople list and process
  def get_instruction(["OR"], instruc_values, fail_instruction, statements) do
    %Plan{
      instruction: instruc_values,
      on_success: :success,
      on_fail: resolve_or_instruction(Map.get(statements, "OR"), fail_instruction)
    }
  end

  # more AND instructions, continue the process
  def get_instruction(new_keys, instruc_values, fail_instruction, statements) do
    %Plan{
      instruction: instruc_values,
      on_success: get_instructions(new_keys, statements),
      on_fail: fail_instruction
    }
  end

  defp resolve_or_instruction([], _) do
    :fail
  end

  defp resolve_or_instruction(instruction_list, fail_instruction) do
    # We reverse the list so the last item is the first to be processed
    instruction_list =
      instruction_list
      |> Enum.reverse()

    last_instruction =
      instruction_list
      |> List.first()

    last_instruction =
      get_instructions(get_clean_key_names(last_instruction), last_instruction, fail_instruction)

    {_, instruction_list} =
      instruction_list
      |> List.pop_at(0)

    Enum.reduce(instruction_list, last_instruction, fn
      x, acc ->
        get_instructions(get_clean_key_names(x), x, acc)
    end)
  end

  defp get_clean_key_names(map) do
    map
    |> get_keys()
    |> Enum.map(&String.replace(&1, @instructions, ""))
    # ["createdAt_gt", "createdAt_lt", "OR"] -> ["OR", "createdAt"]
    |> Enum.uniq()
    # ["OR", "createdAt"] -> ["createdAt", "OR"]
    |> Enum.sort_by(&(&1 == "OR"))
  end

  # by priority `AND` then `OR`
  defp get_keys(map) do
    map |> Map.keys() |> Enum.map(&to_string/1)
  end
end
