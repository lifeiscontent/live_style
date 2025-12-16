defmodule LiveStyle.Watcher do
  @moduledoc """
  File watcher for LiveStyle that regenerates CSS when styles change.

  This watcher monitors the LiveStyle manifest file, which is updated by the
  Elixir compiler when modules using LiveStyle are recompiled. This ensures
  CSS is regenerated only after compilation completes, without arbitrary delays.

  ## Usage in Phoenix

  Add to your endpoint's watchers in `config/dev.exs`:

      config :my_app, MyAppWeb.Endpoint,
        watchers: [
          live_style: {LiveStyle.Watcher, :watch, [[]]}
        ]

  ## Options

  - `:output` - Output path for CSS (default: configured `output_path`)

  Requires the `file_system` dependency (included with `phoenix_live_reload`).
  """

  require Logger

  @doc """
  Starts the watcher process. Called by Phoenix endpoint.

  Watches the manifest file for changes and regenerates CSS when it's updated.

  ## Options

  - `:output` - Output path for CSS (uses configured `output_path` by default)
  """
  def watch(opts \\ []) do
    unless Code.ensure_loaded?(FileSystem) do
      Logger.error("""
      LiveStyle.Watcher requires the :file_system dependency.
      Add {:file_system, "~> 1.0"} to your deps or use phoenix_live_reload which includes it.
      """)

      Process.sleep(:infinity)
    end

    output_path = Keyword.get(opts, :output, LiveStyle.output_path())
    manifest_path = LiveStyle.manifest_path()
    manifest_dir = Path.dirname(manifest_path)

    # Ensure manifest directory exists
    File.mkdir_p!(manifest_dir)

    {:ok, pid} = apply(FileSystem, :start_link, [[dirs: [manifest_dir]]])
    apply(FileSystem, :subscribe, [pid])

    Logger.info("LiveStyle watcher started, watching manifest: #{manifest_path}")

    loop(output_path, manifest_path)
  end

  defp loop(output_path, manifest_path) do
    receive do
      {:file_event, _pid, {path, events}} ->
        if should_rebuild?(path, manifest_path, events) do
          rebuild_css(output_path)
        end

        loop(output_path, manifest_path)

      {:file_event, _pid, :stop} ->
        Logger.info("LiveStyle watcher stopped")
        :ok
    end
  end

  defp should_rebuild?(path, manifest_path, events) do
    # Only rebuild when the manifest file itself changes
    Path.expand(path) == Path.expand(manifest_path) and
      Enum.any?(events, &(&1 in [:modified, :created]))
  end

  defp rebuild_css(output_path) do
    manifest = LiveStyle.read_manifest()

    if has_styles?(manifest) do
      maybe_write_css(manifest, output_path)
    end
  end

  defp has_styles?(manifest) do
    map_size(manifest[:rules] || %{}) > 0 or
      map_size(manifest[:vars] || %{}) > 0 or
      map_size(manifest[:keyframes] || %{}) > 0
  end

  defp maybe_write_css(manifest, output_path) do
    css = LiveStyle.get_all_css()
    current_css = File.read(output_path) |> elem(1)

    if css != current_css do
      write_css(manifest, output_path, css)
    end
  end

  defp write_css(manifest, output_path, css) do
    output_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(output_path, css)

    var_count = map_size(manifest[:vars] || %{})
    keyframe_count = map_size(manifest[:keyframes] || %{})
    rule_count = map_size(manifest[:rules] || %{})

    Logger.info(
      "LiveStyle: #{var_count} vars, #{keyframe_count} keyframes, #{rule_count} rules → #{output_path}"
    )
  end
end
