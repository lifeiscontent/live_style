defmodule LiveStyle.Compiler.Watch do
  @moduledoc false

  # Debounce delay in milliseconds
  @debounce_ms 50

  @spec run_watch_mode(String.t(), String.t(), (String.t() -> non_neg_integer())) ::
          non_neg_integer()
  def run_watch_mode(output, manifest_path, run_once_fun) when is_function(run_once_fun, 1) do
    require Logger

    # Initial generation
    _ = run_once_fun.(output)

    manifest_dir = Path.dirname(manifest_path)

    unless Code.ensure_loaded?(FileSystem) do
      Logger.error("""
      LiveStyle watch mode requires the :file_system dependency.
      Add {:file_system, "~> 1.0"} to your deps or use phoenix_live_reload which includes it.
      """)

      return_error()
    end

    File.mkdir_p!(manifest_dir)

    # Use low latency for faster file change detection on macOS
    {:ok, pid} =
      apply(FileSystem, :start_link, [[dirs: [manifest_dir], latency: 0, no_defer: true]])

    apply(FileSystem, :subscribe, [pid])

    Logger.info("LiveStyle watching for changes...")

    watch_loop(output, manifest_path, run_once_fun, :idle)
  end

  # When no changes pending, wait indefinitely for events
  defp watch_loop(output, manifest_path, run_once_fun, :idle) do
    receive do
      {:file_event, _pid, {path, events}} ->
        if manifest_event?(path, manifest_path, events) do
          require Logger
          Logger.debug("LiveStyle: manifest changed, regenerating CSS...")
          # Start debounce with deadline
          deadline = System.monotonic_time(:millisecond) + @debounce_ms
          watch_loop(output, manifest_path, run_once_fun, {:pending, deadline})
        else
          watch_loop(output, manifest_path, run_once_fun, :idle)
        end

      {:file_event, _pid, :stop} ->
        0
    end
  end

  # When changes pending, use absolute deadline to debounce
  # Only manifest events reset the deadline; other events are consumed without affecting timing
  defp watch_loop(output, manifest_path, run_once_fun, {:pending, deadline}) do
    remaining = max(0, deadline - System.monotonic_time(:millisecond))

    receive do
      {:file_event, _pid, {path, events}} ->
        if manifest_event?(path, manifest_path, events) do
          # Reset debounce deadline for manifest events only
          new_deadline = System.monotonic_time(:millisecond) + @debounce_ms
          watch_loop(output, manifest_path, run_once_fun, {:pending, new_deadline})
        else
          # Non-manifest event: consume but keep same deadline
          watch_loop(output, manifest_path, run_once_fun, {:pending, deadline})
        end

      {:file_event, _pid, :stop} ->
        0
    after
      remaining ->
        _ = run_once_fun.(output)
        watch_loop(output, manifest_path, run_once_fun, :idle)
    end
  end

  defp manifest_event?(path, manifest_path, events) do
    # Normalize both paths to absolute form for comparison
    # FileSystem may send absolute paths while manifest_path might be relative
    normalized_path = Path.expand(path)
    normalized_manifest = Path.expand(manifest_path)

    path_matches = normalized_path == normalized_manifest
    valid_event = Enum.any?(events, &(&1 in [:modified, :created, :renamed, :moved]))

    path_matches and valid_event
  end

  defp return_error, do: 1
end
