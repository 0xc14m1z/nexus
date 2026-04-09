defmodule Nexus.RuntimeConfig.Tools do
  @moduledoc """
  Tool-specific runtime config helpers.

  Tool loading is the first runtime dependency that needs two sources at once:

  - `system_tools` owned by the harness
  - `tools` explicitly configured from runtime JSON
  """

  alias Nexus.RuntimeConfig.Section
  alias Nexus.RuntimeConfig.Source
  alias Nexus.ToolInstance

  @doc """
  Builds all tool instances for one runtime source.
  """
  @spec build_tool_instances(Source.t()) :: {:ok, [ToolInstance.t()]} | {:error, term()}
  def build_tool_instances(source) do
    with {:ok, system_tools} <- build_system_tool_instances(),
         {:ok, configured_tools} <- build_configured_tool_instances(source) do
      {:ok, system_tools ++ configured_tools}
    end
  end

  # System tools are owned by the harness itself, so they always come from app
  # config and stay present even when a JSON runtime file is used.
  defp build_system_tool_instances do
    Application.get_env(:nexus, :system_tools, [])
    |> Section.normalize_tool_sections()
    |> build_tool_instances_with_source(:system)
  end

  # Configured tools are additive extras coming from external runtime config.
  # They are optional, so app-config-only runs simply contribute an empty list.
  defp build_configured_tool_instances({:file, decoded}) do
    decoded
    |> Map.get("tools", [])
    |> Section.normalize_tool_sections()
    |> build_tool_instances_with_source(:configured)
  end

  defp build_configured_tool_instances(:app_config), do: {:ok, []}

  # Tool instances are created only after the adapter/config pairs have been
  # normalized, so validation and source tagging stay in one place.
  defp build_tool_instances_with_source({:ok, sections}, source) do
    Enum.reduce_while(sections, {:ok, []}, fn {adapter, config}, {:ok, acc} ->
      case ToolInstance.new(adapter, config, source: source) do
        {:ok, instance} -> {:cont, {:ok, [instance | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, instances} -> {:ok, Enum.reverse(instances)}
      error -> error
    end
  end

  defp build_tool_instances_with_source({:error, reason}, _source), do: {:error, reason}
end
