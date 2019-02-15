defmodule Nomure.TransactionUtils do
  import FDB.Option

  alias FDB.{Database, Transaction}
  alias FDB.Directory.HighContentionAllocator

  @database_state_key :graph_state
  @atomic_coder FDB.Transaction.Coder.new()

  def get_database_state_key, do: @database_state_key

  def transact(func) when is_function(func, 2) do
    state = Nomure.Database.get_state()

    Database.transact(state.db, fn tr -> func.(tr, state) end)
  end

  def clear_transaction(tr, key, dir) do
    Transaction.clear(tr, key, get_coder_options(dir))
  end

  @doc """
  Set the transaction with the given key and value, it changes the coder based in the dir parameter
  """
  @spec set_transaction(FDB.Transaction.t(), any(), any(), FDB.Database.t()) ::
          :ok
  def set_transaction(tr, key, value, coder) do
    Transaction.set(
      tr,
      key,
      value,
      get_coder_options(coder)
    )
  end

  def get_transaction(tr, key, coder) do
    result = Transaction.get(tr, key, get_coder_options(coder))

    {:ok, tr, result}
  end

  def get_new_uid(tr, state) do
    {a, _} =
      HighContentionAllocator.allocate(state.uid_hca.directory, tr)
      # nil dummy value
      |> FDB.Coder.Integer.decode(nil)

    a
  end

  def add_to_counter(tr, key, addition \\ 1) when is_integer(addition) do
    Transaction.atomic_op(
      tr,
      key,
      mutation_type_add(),
      # 64 bits (8 bytes) counter as documentation mentions
      <<addition::little-integer-unsigned-size(64)>>,
      %{coder: @atomic_coder}
    )
  end

  def get_index_key_value(_value, nil), do: throw("No schema set for the given field")

  def get_index_key_value(value, %{"type" => "integer"}) when is_integer(value),
    do: {:integer, value}

  def get_index_key_value(value, %{"type" => "float"}) when is_float(value), do: {:float32, value}

  def get_index_key_value(value, %{"type" => "boolean"}) when is_boolean(value),
    do: {:boolean, value}

  def get_index_key_value(value, property_schema) when is_binary(value) do
    case property_schema do
      %{"type" => "datetime"} ->
        get_date_time_key_value(value)

      %{"type" => "date"} ->
        get_date_key_value(value)

      %{"type" => "time"} ->
        get_time_key_value(value)

      %{"type" => "enum", "values" => values} ->
        case values[value] do
          nil ->
            throw("Given enum value #{inspect(value)} is not a valid enum property")

          enum_value ->
            {:integer, enum_value}
        end

      %{"type" => "string"} ->
        {:unicode_string, value}
    end
  end

  defp get_date_time_key_value(
         <<year::binary-4, "-", month::binary-2, "-", day::binary-2, "T", hour::binary-2, ":",
           minute::binary-2, ":", second::binary-2, _rest::binary>>
       ) do
    {:nested,
     {{:nested,
       {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()},
        {:integer, day |> parse_integer()}}},
      {:nested,
       {{:integer, hour |> parse_integer()}, {:integer, minute |> parse_integer()},
        {:integer, second |> parse_integer()}}}}}
  end

  defp get_date_time_key_value(<<year::binary-4, "-", month::binary-2, "-", day::binary-2>>) do
    {:nested,
     {{:nested,
       {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()},
        {:integer, day |> parse_integer()}}}}}
  end

  defp get_date_time_key_value(<<year::binary-4, "-", month::binary-2>>) do
    {:nested,
     {{:nested, {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()}}}}}
  end

  defp get_date_time_key_value(<<year::binary-4>>) do
    {:nested, {{:nested, {{:integer, year |> parse_integer()}}}}}
  end

  defp get_date_key_value(<<year::binary-4, "-", month::binary-2, "-", day::binary-2>>) do
    {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()},
     {:integer, day |> parse_integer()}}
  end

  defp get_date_key_value(<<year::binary-4, "-", month::binary-2>>) do
    {{:integer, year |> parse_integer()}, {:integer, month |> parse_integer()}}
  end

  defp get_date_key_value(<<year::binary-4>>) do
    {{:integer, year |> parse_integer()}}
  end

  defp get_time_key_value(<<hour::binary-4, ":", minute::binary-2, ":", second::binary-2>>) do
    {{:integer, hour |> parse_integer()}, {:integer, minute |> parse_integer()},
     {:integer, second |> parse_integer()}}
  end

  defp get_time_key_value(<<hour::binary-4, ":", minute::binary-2>>) do
    {{:integer, hour |> parse_integer()}, {:integer, minute |> parse_integer()}}
  end

  defp get_time_key_value(<<hour::binary-4>>) do
    {{:integer, hour |> parse_integer()}}
  end

  defp parse_integer(value) do
    value |> Integer.parse() |> elem(0)
  end

  defp get_coder_options(coder) do
    %{coder: coder}
  end
end
