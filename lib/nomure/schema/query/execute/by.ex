defmodule Nomure.Schema.Query.Execute.By do
  alias FDB.{KeySelectorRange, Transaction, KeySelector}

  @doc """
  Get the node ids that match the prooperty value
  """
  def property_value(tr, state, node_name, property, value) do
    range = KeySelectorRange.starts_with(get_index_key(node_name, property, value))

    get_property_index_range(tr, state, range)
  end

  @doc """
  Get the node ids that matched the range in between
  """
  def between(
        tr,
        state,
        node_name,
        property,
        greater_than,
        less_than,
        is_great_equal,
        is_less_equal
      ) do
    great_selector = get_greater_than(node_name, property, greater_than, is_great_equal)

    less_selector = get_less_than(node_name, property, less_than, is_less_equal)

    range = KeySelectorRange.range(great_selector, less_selector)

    get_property_index_range(tr, state, range)
  end

  @doc """
  Get the node ids that match greater and/or equal than the given property value
  """
  def greater_than(tr, state, node_name, property, value, true) do
    range =
      KeySelectorRange.range(
        KeySelector.first_greater_or_equal(get_index_key(node_name, property, value), %{
          prefix: :first
        }),
        KeySelector.first_greater_or_equal(get_end_key(node_name, property), %{
          prefix: :last
        })
      )

    get_property_index_range(tr, state, range)
  end

  def greater_than(tr, state, node_name, property, value, false) do
    range =
      KeySelectorRange.range(
        KeySelector.first_greater_than(get_index_key(node_name, property, value), %{
          prefix: :first
        }),
        KeySelector.first_greater_or_equal(get_end_key(node_name, property), %{
          prefix: :last
        })
      )

    get_property_index_range(tr, state, range)
  end

  @doc """
  Get the node ids that match less and/or equal than the given property value
  """
  def less_than(tr, state, node_name, property, value, true) do
    range =
      KeySelectorRange.range(
        KeySelector.last_less_or_equal(get_index_key(node_name, property, value), %{
          prefix: :first
        }),
        KeySelector.last_less_or_equal(get_end_key(node_name, property), %{
          prefix: :last
        })
      )

    get_property_index_range(tr, state, range)
  end

  def less_than(tr, state, node_name, property, value, false) do
    range =
      KeySelectorRange.range(
        KeySelector.last_less_than(get_index_key(node_name, property, value), %{prefix: :first}),
        KeySelector.last_less_or_equal(get_end_key(node_name, property), %{
          prefix: :last
        })
      )

    get_property_index_range(tr, state, range)
  end

  # Greater or equal than
  defp get_greater_than(node_name, property, value, true) do
    KeySelector.first_greater_or_equal(get_index_key(node_name, property, value))
  end

  # Greater than
  defp get_greater_than(node_name, property, value, false) do
    KeySelector.first_greater_than(get_index_key(node_name, property, value))
  end

  # Less or equal than
  defp get_less_than(node_name, property, value, true) do
    KeySelector.last_less_or_equal(get_index_key(node_name, property, value))
  end

  # Less than
  defp get_less_than(node_name, property, value, false) do
    KeySelector.last_less_than(get_index_key(node_name, property, value))
  end

  defp get_index_key(node_name, property, value),
    do: {node_name, property, {{get_property_type(value), value}}}

  defp get_end_key(node_name, property),
    do: {node_name, property}

  defp get_property_type(value) when is_integer(value), do: :integer
  defp get_property_type(value) when is_float(value), do: :float32
  defp get_property_type(value) when is_boolean(value), do: :boolean
  defp get_property_type(value) when is_binary(value), do: :unicode_string

  defp get_uid_from_encoded({{node_name, _, {_, {_, uid}}}, _}) do
    {node_name, uid}
  end

  defp get_property_index_range(tr, state, range) do
    Transaction.get_range(tr, range, %{coder: state.properties_index.coder})
    |> Enum.to_list()
    # cleanup the result list
    |> Enum.map(&get_uid_from_encoded/1)
  end
end
