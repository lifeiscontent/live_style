defmodule Mix.Tasks.LiveStyle.Inspect do
  @moduledoc """
  Inspects LiveStyle class definitions, showing generated CSS and properties.

  ## Usage

      mix live_style.inspect MyAppWeb.Button primary
      mix live_style.inspect MyAppWeb.Button base primary
      mix live_style.inspect MyAppWeb.Button --list

  ## Options

    * `--css` - Show raw CSS output instead of property breakdown
    * `--list` - List all class definitions in the module

  ## Examples

      $ mix live_style.inspect MyAppWeb.CoreComponents btn_base

      :btn_base
      class: x1a2b3c4 x5d6e7f8

        display: x1a2b3c4
        padding: x5d6e7f8

      $ mix live_style.inspect MyAppWeb.CoreComponents btn_base btn_primary --css
      .x1a2b3c4:not(#\\#){display:flex}
      .x5d6e7f8:not(#\\#){padding:8px 16px}

      $ mix live_style.inspect MyAppWeb.CoreComponents --list
      Classes in MyAppWeb.CoreComponents:
        :btn_base
        :btn_primary
        :btn_secondary
  """

  use Mix.Task

  @shortdoc "Inspect LiveStyle class definitions"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: [css: :boolean, list: :boolean])

    case args do
      [] ->
        print_usage()

      [module_string | class_names] ->
        Mix.Task.run("app.start")
        module = load_module!(module_string)
        execute_command(module, class_names, opts)
    end
  end

  defp print_usage do
    Mix.shell().error("Usage: mix live_style.inspect Module [class_name...] [--css] [--list]")
    Mix.shell().error("Example: mix live_style.inspect MyAppWeb.Button primary")
  end

  defp load_module!(module_string) do
    module = Module.concat([module_string])

    unless Code.ensure_loaded?(module) do
      Mix.shell().error("Module #{module_string} not found")
      exit({:shutdown, 1})
    end

    unless function_exported?(module, :__live_style__, 1) do
      Mix.shell().error("Module #{module_string} is not a LiveStyle module")
      exit({:shutdown, 1})
    end

    module
  end

  defp execute_command(module, class_names, opts) do
    cond do
      opts[:list] ->
        print_list(module)

      opts[:css] && class_names != [] ->
        class_atoms = Enum.map(class_names, &String.to_existing_atom/1)
        print_css(module, class_atoms)

      class_names != [] ->
        class_atoms = Enum.map(class_names, &String.to_existing_atom/1)
        print_inspection(module, class_atoms)

      true ->
        Mix.shell().error("Please specify class names or use --list")
        Mix.shell().error("Example: mix live_style.inspect MyAppWeb.Button primary")
    end
  end

  defp print_list(module) do
    classes = LiveStyle.Dev.list(module)

    Mix.shell().info("")
    Mix.shell().info("Classes in #{inspect(module)}:")

    if classes == [] do
      Mix.shell().info("  (no classes defined)")
    else
      for class <- classes do
        Mix.shell().info("  :#{class}")
      end
    end

    Mix.shell().info("")
  end

  defp print_inspection(module, class_atoms) do
    case class_atoms do
      [single] ->
        LiveStyle.Dev.show(module, single)

      multiple ->
        LiveStyle.Dev.diff(module, multiple)
    end
  end

  defp print_css(module, class_atoms) do
    css = LiveStyle.Dev.css(module, class_atoms)

    if css == "" do
      Mix.shell().info("(no CSS generated)")
    else
      Mix.shell().info(css)
    end
  end
end
