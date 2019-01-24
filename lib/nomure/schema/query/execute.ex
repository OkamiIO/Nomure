defmodule Nomure.Schema.Query.Execute do
  alias Nomure.Schema.Plan
  alias Nomure.Schema.Query.Execute.By

  def where(tr, state, node_name, result, %Plan{instruction: {property, value}} = plan)
      when not is_map(value) do
    By.property_value(tr, state, node_name, property, value)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(tr, state, node_name, result, %Plan{instruction: {property, %{"eq" => value}}} = plan) do
    By.property_value(tr, state, node_name, property, value)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(
        tr,
        state,
        node_name,
        result,
        %Plan{instruction: {property, %{"gt" => greater, "lt" => less}}} = plan
      )
      when greater > less do
    By.between(tr, state, node_name, property, greater, less, false, false)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(
        tr,
        state,
        node_name,
        result,
        %Plan{instruction: {property, %{"gt" => greater, "lte" => less}}} = plan
      )
      when greater > less do
    By.between(tr, state, node_name, property, greater, less, false, true)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(
        tr,
        state,
        node_name,
        result,
        %Plan{instruction: {property, %{"gte" => greater, "lt" => less}}} = plan
      )
      when greater > less do
    By.between(tr, state, node_name, property, greater, less, true, false)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(
        tr,
        state,
        node_name,
        result,
        %Plan{instruction: {property, %{"gte" => greater, "lte" => less}}} = plan
      )
      when greater > less do
    By.between(tr, state, node_name, property, greater, less, true, true)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(
        tr,
        state,
        node_name,
        result,
        %Plan{instruction: {property, %{"gt" => greater}}} = plan
      ) do
    By.greater_than(tr, state, node_name, property, greater, false)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(
        tr,
        state,
        node_name,
        result,
        %Plan{instruction: {property, %{"gte" => greater}}} = plan
      ) do
    By.greater_than(tr, state, node_name, property, greater, true)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(tr, state, node_name, result, %Plan{instruction: {property, %{"lt" => less}}} = plan) do
    By.less_than(tr, state, node_name, property, less, false)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(tr, state, node_name, result, %Plan{instruction: {property, %{"lte" => less}}} = plan) do
    By.less_than(tr, state, node_name, property, less, true)
    |> evaluate_result(node_name, result, plan, tr, state)
  end

  def where(
        _tr,
        _state,
        _node_name,
        _result,
        %Plan{instruction: {_property, %{"intersect" => _intersect}}} = _plan
      ) do
    # TODO
    MapSet.new()
  end

  # fail all because is AND operation and no OR operation left
  defp evaluate_result([], _node_name, _result, %Plan{on_fail: :fail}, _tr, _state) do
    []
  end

  # we execute OR operation because AND fails
  defp evaluate_result([], node_name, _result, %Plan{on_fail: %Plan{} = on_fail_plan}, tr, state) do
    where(tr, state, node_name, nil, on_fail_plan)
  end

  # no more AND operations, instruction contains data so we return it
  defp evaluate_result(instruction, _node_name, nil, %Plan{on_success: :success}, _tr, _state) do
    # on_success
    instruction
  end

  # execute the next AND instruction and send the previous `instruction` result
  defp evaluate_result(
         instruction,
         node_name,
         nil,
         %Plan{on_success: %Plan{} = on_success_plan},
         tr,
         state
       ) do
    # on_success
    where(tr, state, node_name, instruction, on_success_plan)
  end

  defp evaluate_result(instruction, node_name, result, plan, tr, state) do
    new_result =
      MapSet.intersection(instruction |> MapSet.new(), result |> MapSet.new())
      |> MapSet.to_list()

    evaluate_result(new_result, node_name, nil, plan, tr, state)
  end
end
