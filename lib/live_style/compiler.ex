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

  ## Manual CSS Generation

      LiveStyle.Compiler.run(:default, [])

  ## Functions

  - `run/2` - Run CSS generation for a profile (with optional `--watch` flag)
  - `install_and_run/2` - Alias for `run/2` (Tailwind API compatibility)
  - `write_css/1` - Write CSS to the configured output path
  """

  alias LiveStyle.Compiler.{Runner, Writer}

  @spec run(atom(), [String.t()]) :: non_neg_integer()
  def run(profile, extra_args), do: Runner.run(profile, extra_args)

  @spec install_and_run(atom(), [String.t()]) :: non_neg_integer()
  def install_and_run(profile, args), do: Runner.install_and_run(profile, args)

  @spec write_css(keyword()) :: :ok | {:error, term()}
  def write_css(opts \\ []), do: Writer.write_css(opts)
end
