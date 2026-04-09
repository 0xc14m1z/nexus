defmodule Nexus.ToolInstanceTest do
  use ExUnit.Case

  alias Nexus.ToolInstance
  alias Nexus.Tools.CurrentTime

  test "new/3 builds a configured tool instance from a valid adapter" do
    assert {:ok, %ToolInstance{adapter: CurrentTime, config: %{}, source: :configured}} =
             ToolInstance.new(CurrentTime, %{})
  end

  test "new/3 can mark a tool as system-provided" do
    assert {:ok, %ToolInstance{adapter: CurrentTime, source: :system}} =
             ToolInstance.new(CurrentTime, %{}, source: :system)
  end

  test "new/3 rejects an adapter that does not implement the tool behaviour" do
    assert {:error, {:invalid_tool, String}} = ToolInstance.new(String, %{})
  end

  test "definition/1 delegates to the configured adapter" do
    tool = %ToolInstance{adapter: CurrentTime, config: %{}, source: :configured}

    assert %{
             name: "current_time",
             description: _description,
             input_schema: %{"type" => "object"}
           } = ToolInstance.definition(tool)
  end
end
