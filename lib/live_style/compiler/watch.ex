defmodule LiveStyle.Compiler.Watch do
  @moduledoc false

  alias LiveStyle.Compiler.ModuleData

  @spec run_watch_mode(String.t(), String.t() | nil, String.t(), (String.t(), String.t() | nil ->
                                                                    non_neg_integer())) ::
          non_neg_integer()
  def run_watch_mode(output, input, manifest_path, run_once_fun)
      when is_function(run_once_fun, 2) do
    require Logger

    # Initial generation
    _ = run_once_fun.(output, input)

    manifest_dir = Path.dirname(manifest_path)
    modules_dir = ModuleData.modules_dir()

    unless Code.ensure_loaded?(FileSystem) do
      Logger.error("""
      LiveStyle watch mode requires the :file_system dependency.
      Add {:file_system, "~> 1.0"} to your deps or use phoenix_live_reload which includes it.
      """)

      return_error()
    end

    File.mkdir_p!(manifest_dir)
    File.mkdir_p!(modules_dir)

    # Watch modules directory AND input file directory (if configured)
    # Per-module files are the source of truth - they're written during __before_compile__
    # We merge them into the manifest before regenerating CSS
    # Watching the manifest would cause infinite loops since merge_module_data() writes to it
    watch_dirs = [modules_dir] ++ if(input, do: [Path.dirname(input)], else: [])

    {:ok, pid} =
      apply(FileSystem, :start_link, [
        [dirs: watch_dirs, latency: 0, no_defer: true]
      ])

    apply(FileSystem, :subscribe, [pid])

    Logger.info("LiveStyle watching #{modules_dir} for changes...")

    # Track content hash to only regenerate when data actually changes
    # No debouncing needed - the hash check naturally handles duplicate events
    initial_hash = compute_modules_hash(modules_dir)
    watch_loop(output, input, modules_dir, run_once_fun, initial_hash)
  end

  # Main watch loop - process events immediately, rely on content hash to skip duplicates
  defp watch_loop(output, input, modules_dir, run_once_fun, last_hash) do
    receive do
      {:file_event, _pid, {path, events}} ->
        new_hash =
          cond do
            module_file_event?(path, modules_dir, events) ->
              maybe_regenerate(output, input, modules_dir, run_once_fun, last_hash)

            input_file_event?(path, input, events) ->
              # Input file changed - regenerate without checking module hash
              _ = run_once_fun.(output, input)
              last_hash

            true ->
              last_hash
          end

        watch_loop(output, input, modules_dir, run_once_fun, new_hash)

      {:file_event, _pid, :stop} ->
        0
    end
  end

  # Check if content changed, regenerate if so
  # Returns the new content hash
  defp maybe_regenerate(output, input, modules_dir, run_once_fun, last_hash) do
    new_hash = compute_modules_hash(modules_dir)

    if new_hash != last_hash do
      # Content changed - merge and regenerate
      LiveStyle.Storage.merge_module_data()
      _ = run_once_fun.(output, input)
    end

    new_hash
  end

  # Compute a hash of all module data files to detect actual changes
  defp compute_modules_hash(modules_dir) do
    case File.ls(modules_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".etf"))
        |> Enum.sort()
        |> Enum.map(&file_content_hash(modules_dir, &1))
        |> :erlang.md5()

      {:error, _} ->
        <<>>
    end
  end

  defp file_content_hash(dir, file) do
    case File.read(Path.join(dir, file)) do
      {:ok, content} -> :erlang.md5(content)
      {:error, _} -> <<>>
    end
  end

  # Check if this is a per-module file event (.etf file in modules directory)
  defp module_file_event?(path, modules_dir, events) do
    normalized_path = Path.expand(path)
    normalized_modules_dir = Path.expand(modules_dir)

    valid_event = Enum.any?(events, &(&1 in [:modified, :created, :renamed, :moved]))

    is_module_file =
      String.starts_with?(normalized_path, normalized_modules_dir <> "/") and
        String.ends_with?(normalized_path, ".etf")

    valid_event and is_module_file
  end

  # Check if this is an input file event
  defp input_file_event?(_path, nil, _events), do: false

  defp input_file_event?(path, input, events) do
    normalized_path = Path.expand(path)
    normalized_input = Path.expand(input)

    valid_event = Enum.any?(events, &(&1 in [:modified, :created, :renamed, :moved]))

    valid_event and normalized_path == normalized_input
  end

  defp return_error, do: 1
end
