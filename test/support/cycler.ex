defmodule CloudWatch.Cycler do
  def start_link do
    Agent.start_link(fn -> %{index: 0, responses: []} end, name: __MODULE__)
  end

  def reset_responses(responses) do
    Agent.update(__MODULE__, &Map.merge(&1, %{index: 0, responses: responses}))
  end

  def next_response do
    Agent.get_and_update(__MODULE__, fn state ->
      {Enum.at(state.responses, state.index), Map.merge(state, %{index: state.index + 1})}
    end)
  end
end
