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

    watch_loop(output, manifest_path, run_once_fun, _pending = false)
  end

  # When no changes pending, wait indefinitely for events
  defp watch_loop(output, manifest_path, run_once_fun, false = _pending) do
    receive do
      {:file_event, _pid, {path, events}} ->
        if manifest_event?(path, manifest_path, events) do
          watch_loop(output, manifest_path, run_once_fun, _pending = true)
        else
          watch_loop(output, manifest_path, run_once_fun, _pending = false)
        end

      {:file_event, _pid, :stop} ->
        0
    end
  end

  # When changes pending, use timeout to debounce
  defp watch_loop(output, manifest_path, run_once_fun, true = _pending) do
    receive do
      {:file_event, _pid, {path, events}} ->
        if manifest_event?(path, manifest_path, events) do
          # Reset debounce timer
          watch_loop(output, manifest_path, run_once_fun, _pending = true)
        else
          watch_loop(output, manifest_path, run_once_fun, _pending = true)
        end

      {:file_event, _pid, :stop} ->
        0
    after
      @debounce_ms ->
        _ = run_once_fun.(output)
        watch_loop(output, manifest_path, run_once_fun, _pending = false)
    end
  end

  defp manifest_event?(path, manifest_path, events) do
    Path.expand(path) == Path.expand(manifest_path) and
      Enum.any?(events, &(&1 in [:modified, :created, :renamed, :moved]))
  end

  defp return_error, do: 1
end
