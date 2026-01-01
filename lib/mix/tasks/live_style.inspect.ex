defmodule Mix.Tasks.LiveStyle.Inspect do
  @moduledoc """
  Inspects a LiveStyle class, showing its generated CSS and properties.

  ## Usage

      mix live_style.inspect MyApp.Components.Button button
      mix live_style.inspect MyApp.Components.Button button primary

  ## Options

    * `--css` - Show raw CSS output instead of property breakdown

  ## Examples

      $ mix live_style.inspect MyAppWeb.CoreComponents btn_base
      
      :btn_base
      class: x1a2b3c4 x5d6e7f8

      display: flex (x1a2b3c4)
      padding: 8px 16px (x5d6e7f8)

      $ mix live_style.inspect MyAppWeb.CoreComponents btn_base btn_primary --css
      .x1a2b3c4:not(#\\#){display:flex}...
  """

  use Mix.Task

  @shortdoc "Inspect a LiveStyle class definition"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: [css: :boolean])

    case args do
      [] ->
        Mix.shell().error("Usage: mix live_style.inspect Module class_name [class_name...]")
        Mix.shell().error("Example: mix live_style.inspect MyApp.Button button")

      [module_string | class_names] when class_names != [] ->
        Mix.Task.run("app.start")

        module = Module.concat([module_string])

        unless Code.ensure_loaded?(module) do
          Mix.shell().error("Module #{module_string} not found")
          exit({:shutdown, 1})
        end

        unless function_exported?(module, :__live_style__, 1) do
          Mix.shell().error("Module #{module_string} is not a LiveStyle module")
          exit({:shutdown, 1})
        end

        class_atoms = Enum.map(class_names, &String.to_atom/1)

        if opts[:css] do
          print_css(module, class_atoms)
        else
          print_inspection(module, class_atoms)
        end

      [_module_string] ->
        Mix.shell().error("Please specify at least one class name")
        Mix.shell().error("Example: mix live_style.inspect MyApp.Button button")
    end
  end

  defp print_inspection(module, class_atoms) do
    Enum.each(class_atoms, fn class_name ->
      LiveStyle.Dev.pp(module, class_name)
    end)

    if match?([_, _ | _], class_atoms) do
      diff = LiveStyle.Dev.diff(module, class_atoms)
      Mix.shell().info("")
      Mix.shell().info("  #{IO.ANSI.bright()}Merged result:#{IO.ANSI.reset()}")
      Mix.shell().info("  class: #{diff.merged_class}")
      Mix.shell().info("")
    end
  end

  defp print_css(module, class_atoms) do
    css = LiveStyle.Dev.css(module, class_atoms)
    Mix.shell().info(css)
  end
end
