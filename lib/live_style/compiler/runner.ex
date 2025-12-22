defmodule LiveStyle.Compiler.Runner do
  @moduledoc false

  alias LiveStyle.Compiler.{Watch, Writer}
  alias LiveStyle.Config

  @spec run(atom(), [String.t()]) :: non_neg_integer()
  def run(profile, extra_args) when is_atom(profile) and is_list(extra_args) do
    config = Config.config_for!(profile)
    output = Keyword.get(config, :output, Config.output_path())
    cd = Keyword.get(config, :cd, File.cwd!())

    original_cwd = File.cwd!()

    try do
      if cd != original_cwd, do: File.cd!(cd)

      if "--watch" in extra_args do
        Watch.run_watch_mode(output, LiveStyle.Storage.path(), &Writer.run_once/1)
      else
        Writer.run_once(output)
      end
    after
      if cd != original_cwd, do: File.cd!(original_cwd)
    end
  end

  @spec install_and_run(atom(), [String.t()]) :: non_neg_integer()
  def install_and_run(profile, args) do
    run(profile, args)
  end
end
