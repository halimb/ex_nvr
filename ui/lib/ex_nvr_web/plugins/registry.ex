defmodule ExNVRWeb.PluginRegistry do

  def plugins() do
    Application.get_env(:ex_nvr, :plugins, [])
  end

  def routes(), do: collect(:routes, [])

  def menu_entries(), do: collect(:menu_entries, [])

  def components(), do: collect(:components, %{})

  def theme(), do: collect(:theme, %{})

  def render_component(name, assigns, fallback)  do
    components()
    |> Map.get_lazy(name, fn -> fallback end)
    |> then(& &1.(assigns))
  end

  defp collect(collection, default) do
    plugins()
    |> Enum.map(&lookup(&1, collection, default))
    |> merge(default)
  end

  defp lookup(plugin, collection, default) do
    case Code.ensure_loaded(plugin) do
      {:module, _} ->
        if function_exported?(plugin, collection, 0) do
          apply(plugin, collection, [])
        else
          default
        end

      _ ->
        IO.warn("Plugin #{inspect(plugin)} not loaded")
        default
    end
  end

  defp merge(results, %{}), do: Enum.reduce(results, %{}, &Map.merge/2)

  defp merge(results, []), do: List.flatten(results)
end
