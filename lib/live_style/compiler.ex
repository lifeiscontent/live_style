defmodule LiveStyle.Compiler do
  @moduledoc """
  Compiler and tooling functions for LiveStyle.

  This module provides functions used by mix tasks and watchers for
  CSS generation and validation. These are not needed at runtime.

  ## Development Watcher

  For automatic CSS regeneration during development, configure a watcher
  in your Phoenix endpoint:

      # config/dev.exs
      config :my_app, MyAppWeb.Endpoint,
        watchers: [
          live_style: {LiveStyle.Compiler, :run, [:default, ~w(--watch)]}
        ]

  The watcher monitors the LiveStyle manifest file and regenerates CSS
  whenever styles are recompiled. This requires the `file_system` dependency
  (included with `phoenix_live_reload`).

  ## Manual CSS Generation

  Generate CSS without watching:

      LiveStyle.Compiler.run(:default, [])

  ## Profile Configuration

  Configure profiles in your `config/config.exs`:

      config :live_style,
        default: [
          output: "priv/static/assets/live.css",
          cd: Path.expand("..", __DIR__)
        ]

  ## Functions

  - `run/2` - Run CSS generation for a profile (with optional `--watch` flag)
  - `install_and_run/2` - Alias for `run/2` (Tailwind API compatibility)
  - `write_css/1` - Write CSS to the configured output path
  """

  alias LiveStyle.Config

  @doc """
  Runs LiveStyle CSS generation for the given profile.

  The profile configuration should specify:
  - `:output` - Output path for CSS file
  - `:cd` - Working directory (optional)

  Returns `0` on success, `1` on error (matching Tailwind's exit code pattern).

  ## Example

      LiveStyle.Compiler.run(:default, [])
      LiveStyle.Compiler.run(:default, ["--watch"])
  """
  def run(profile, extra_args) when is_atom(profile) and is_list(extra_args) do
    config = Config.config_for!(profile)
    output = Keyword.get(config, :output, Config.output_path())
    cd = Keyword.get(config, :cd, File.cwd!())

    # Change to configured directory
    original_cwd = File.cwd!()

    try do
      if cd != original_cwd, do: File.cd!(cd)

      watch_mode? = "--watch" in extra_args

      if watch_mode? do
        run_watch_mode(output)
      else
        run_once(output)
      end
    after
      if cd != original_cwd, do: File.cd!(original_cwd)
    end
  end

  @doc """
  Runs LiveStyle CSS generation for the given profile.

  This is equivalent to `run/2` since LiveStyle doesn't require installation
  (it's pure Elixir). Provided for API compatibility with Tailwind's watcher pattern.

  ## Usage in Phoenix Endpoint

      config :my_app, MyAppWeb.Endpoint,
        watchers: [
          live_style: {LiveStyle.Compiler, :install_and_run, [:default, ~w(--watch)]}
        ]
  """
  def install_and_run(profile, args) do
    run(profile, args)
  end

  @doc """
  Writes CSS to the configured output path.

  ## Options

  - `:output_path` - Override the output path (default: configured `output_path`)
  - `:log` - Callback function for logging (receives `{:written, var_count, keyframe_count, rule_count, path}`)

  ## Examples

      LiveStyle.Compiler.write_css()
      LiveStyle.Compiler.write_css(output_path: "custom/path.css")
      LiveStyle.Compiler.write_css(log: fn info -> IO.inspect(info) end)
  """
  def write_css(opts \\ []) do
    output = Keyword.get(opts, :output_path, Config.output_path())
    log_fn = Keyword.get(opts, :log)

    manifest = LiveStyle.Storage.read()

    case LiveStyle.CSS.write(output, stats: true) do
      {:ok, :written} ->
        if log_fn do
          var_count = map_size(manifest.vars)
          keyframe_count = map_size(manifest.keyframes)
          class_count = map_size(manifest.classes)
          log_fn.({:written, var_count, keyframe_count, class_count, output})
        end

        :ok

      {:ok, :unchanged} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_once(output) do
    case write_css(output_path: output, log: &log_run/1) do
      :ok -> 0
      {:error, _reason} -> 1
    end
  end

  defp run_watch_mode(output) do
    require Logger

    # Initial generation
    run_once(output)

    manifest_path = LiveStyle.Storage.path()
    manifest_dir = Path.dirname(manifest_path)

    unless Code.ensure_loaded?(FileSystem) do
      Logger.error("""
      LiveStyle watch mode requires the :file_system dependency.
      Add {:file_system, "~> 1.0"} to your deps or use phoenix_live_reload which includes it.
      """)

      return_error()
    end

    File.mkdir_p!(manifest_dir)

    {:ok, pid} = apply(FileSystem, :start_link, [[dirs: [manifest_dir]]])
    apply(FileSystem, :subscribe, [pid])

    Logger.info("LiveStyle watching for changes...")

    watch_loop(output, manifest_path)
  end

  defp watch_loop(output, manifest_path) do
    receive do
      {:file_event, _pid, {path, events}} ->
        if Path.expand(path) == Path.expand(manifest_path) and
             Enum.any?(events, &(&1 in [:modified, :created])) do
          run_once(output)
        end

        watch_loop(output, manifest_path)

      {:file_event, _pid, :stop} ->
        0
    end
  end

  defp return_error, do: 1

  defp log_run({:written, var_count, keyframe_count, rule_count, output_path}) do
    require Logger

    Logger.info(
      "LiveStyle: #{var_count} vars, #{keyframe_count} keyframes, #{rule_count} rules → #{output_path}"
    )
  end
end
