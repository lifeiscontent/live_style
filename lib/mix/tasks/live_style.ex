defmodule Mix.Tasks.LiveStyle do
  @moduledoc """
  Invokes LiveStyle CSS generation with the given profile and args.

  ## Usage

      $ mix live_style PROFILE [ARGS]

  ## Examples

      # Generate CSS once
      $ mix live_style default

      # Watch mode for development
      $ mix live_style default --watch

  ## Profile Configuration

  The profile must be defined in your config files:

      config :live_style,
        default: [
          output: "priv/static/assets/live.css",
          cd: Path.expand("..", __DIR__)
        ]

  ## Arguments

  - `--watch` - Watch for changes and regenerate CSS automatically

  ## Task Options

  Options for the Mix task itself (must be given before the profile):

  - `--runtime-config` - Load the runtime configuration before executing

  Example:

      $ mix live_style --runtime-config default

  ## Development Watcher

  For development, it's typically easier to configure a watcher in your
  Phoenix endpoint instead of running this task manually:

      # config/dev.exs
      config :my_app, MyAppWeb.Endpoint,
        watchers: [
          live_style: {LiveStyle.Compiler, :run, [:default, ~w(--watch)]}
        ]
  """

  @shortdoc "Invokes LiveStyle with the profile and args"
  @compile {:no_warn_undefined, Mix}

  use Mix.Task

  alias LiveStyle.Compiler.Runner

  @impl true
  def run(args) do
    switches = [runtime_config: :boolean]
    {opts, remaining_args} = OptionParser.parse_head!(args, switches: switches)

    if opts[:runtime_config] do
      Mix.Task.run("app.config")
    else
      Mix.Task.run("loadpaths")
      Application.ensure_all_started(:live_style)
    end

    Mix.Task.reenable("live_style")
    run_profile(remaining_args)
  end

  defp run_profile([profile | args]) do
    profile_atom = string_to_profile_atom(profile)

    case Runner.run(profile_atom, args) do
      0 ->
        :ok

      status ->
        Mix.raise("`mix live_style #{Enum.join([profile | args], " ")}` exited with #{status}")
    end
  end

  defp run_profile([]) do
    Mix.raise("`mix live_style` expects the profile as argument")
  end

  defp string_to_profile_atom(profile) do
    String.to_existing_atom(profile)
  rescue
    ArgumentError ->
      Mix.raise("""
      Unknown LiveStyle profile: #{profile}

      Make sure the profile is configured in your config files:

          config :live_style,
            #{profile}: [
              output: "priv/static/assets/app.css",
              cd: Path.expand("..", __DIR__)
            ]
      """)
  end
end
