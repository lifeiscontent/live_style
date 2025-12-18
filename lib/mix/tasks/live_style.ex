defmodule Mix.Tasks.LiveStyle do
  @moduledoc """
  Invokes LiveStyle CSS generation with the given profile and args.

  Usage:

      $ mix live_style PROFILE [ARGS]

  Example:

      $ mix live_style default
      $ mix live_style default --watch

  The profile must be defined in your config files:

      config :live_style,
        default: [
          output: "priv/static/assets/live.css",
          cd: Path.expand("..", __DIR__)
        ]

  ## Options

    * `--runtime-config` - load the runtime configuration
      before executing command

  Note flags to control this Mix task must be given before the
  profile:

      $ mix live_style --runtime-config default
  """

  @shortdoc "Invokes LiveStyle with the profile and args"
  @compile {:no_warn_undefined, Mix}

  use Mix.Task

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
    case LiveStyle.run(String.to_atom(profile), args) do
      0 ->
        :ok

      status ->
        Mix.raise("`mix live_style #{Enum.join([profile | args], " ")}` exited with #{status}")
    end
  end

  defp run_profile([]) do
    Mix.raise("`mix live_style` expects the profile as argument")
  end
end
