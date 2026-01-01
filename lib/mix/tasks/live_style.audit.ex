defmodule Mix.Tasks.LiveStyle.Audit do
  @moduledoc """
  Audits LiveStyle class definitions to find potentially unused classes.

  This task scans your codebase for `class/2` definitions and checks if
  they are referenced anywhere in templates or code.

  ## Usage

      mix live_style.audit
      mix live_style.audit --path lib/my_app_web

  ## Options

    * `--path` - Directory to scan (default: "lib")
    * `--format` - Output format: "text" or "json" (default: "text")

  ## How It Works

  1. Finds all modules that `use LiveStyle`
  2. Extracts class names defined via `class/2`
  3. Searches for references to those classes in `.ex`, `.exs`, and `.heex` files
  4. Reports classes that have no apparent references

  ## Limitations

  - Dynamic class references (e.g., `css(assigns.variant)`) cannot be detected
  - Classes referenced via variables may show as unused
  - This is a heuristic tool - manual review is recommended before removing classes

  ## Examples

      $ mix live_style.audit
      
      Scanning lib/ for LiveStyle classes...
      
      Found 3 potentially unused classes:
      
        MyAppWeb.CoreComponents
          :deprecated_button (lib/my_app_web/components/core_components.ex:45)
          :old_card (lib/my_app_web/components/core_components.ex:89)
        
        MyAppWeb.Layouts
          :legacy_header (lib/my_app_web/components/layouts.ex:12)

      $ mix live_style.audit --format json
      [{"module":"MyAppWeb.CoreComponents","class":"deprecated_button","file":"...","line":45}]
  """

  use Mix.Task

  @shortdoc "Find potentially unused LiveStyle class definitions"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [path: :string, format: :string],
        aliases: [p: :path, f: :format]
      )

    path = Keyword.get(opts, :path, "lib")
    format = Keyword.get(opts, :format, "text")

    Mix.Task.run("app.start")

    Mix.shell().info("Scanning #{path}/ for LiveStyle classes...\n")

    # Step 1: Find all class definitions
    definitions = find_class_definitions(path)

    if definitions == [] do
      Mix.shell().info("No LiveStyle class definitions found.")
      exit(:normal)
    end

    # Step 2: Find all references in templates and code
    references = find_class_references(path)

    # Step 3: Find unused classes
    unused = find_unused(definitions, references)

    # Step 4: Output results
    case format do
      "json" -> output_json(unused)
      _ -> output_text(unused, definitions)
    end
  end

  defp find_class_definitions(path) do
    path
    |> Path.join("**/*.{ex,exs}")
    |> Path.wildcard()
    |> Enum.flat_map(&extract_definitions/1)
  end

  defp extract_definitions(file) do
    content = File.read!(file)

    # Match class(:name, ...) definitions
    # The pattern must be at the start of a line (after whitespace) to avoid matching
    # inside other expressions
    ~r/^\s*class\(\s*:([a-z_][a-z0-9_]*)\s*,/m
    |> Regex.scan(content)
    |> Enum.map(fn [full_match, class_name] ->
      # Find line number by locating the match in content
      line = count_lines_for_match(content, full_match)
      module = extract_module_name(content)

      %{
        module: module,
        class: String.to_atom(class_name),
        file: file,
        line: line
      }
    end)
  end

  defp extract_module_name(content) do
    case Regex.run(~r/defmodule\s+([\w.]+)/, content) do
      [_, module] -> module
      _ -> "Unknown"
    end
  end

  defp count_lines_for_match(content, match) do
    # Find the position of the match and count lines up to that point
    case :binary.match(content, match) do
      {pos, _len} ->
        content
        |> :binary.part(0, pos)
        |> String.split("\n")
        |> length()

      :nomatch ->
        0
    end
  end

  defp find_class_references(path) do
    ex_refs = find_refs_in_ex_files(path)
    heex_refs = find_refs_in_heex_files(path)

    MapSet.union(ex_refs, heex_refs)
  end

  defp find_refs_in_ex_files(path) do
    path
    |> Path.join("**/*.{ex,exs}")
    |> Path.wildcard()
    |> Enum.flat_map(fn file ->
      content = File.read!(file)

      # Find css(:name) calls
      css_refs =
        ~r/(?<![_a-z])css\(\s*:([a-z_][a-z0-9_]*)/
        |> Regex.scan(content)
        |> Enum.map(fn [_, name] -> String.to_atom(name) end)

      # Find class references in lists like css([:button, :primary])
      list_refs =
        ~r/(?<![_a-z])css\(\s*\[([^\]]+)\]\s*\)/
        |> Regex.scan(content)
        |> Enum.flat_map(&extract_atoms_from_list/1)

      css_refs ++ list_refs
    end)
    |> MapSet.new()
  end

  defp find_refs_in_heex_files(path) do
    path
    |> Path.join("**/*.heex")
    |> Path.wildcard()
    |> Enum.flat_map(fn file ->
      content = File.read!(file)

      # Find css(@name) in templates
      css_refs =
        ~r/[^_]css\(\s*@?:?(\w+)/
        |> Regex.scan(content)
        |> Enum.map(fn [_, name] -> String.to_atom(name) end)

      css_refs
    end)
    |> MapSet.new()
  end

  defp extract_atoms_from_list([_, list_content]) do
    ~r/:([a-z_][a-z0-9_]*)/
    |> Regex.scan(list_content)
    |> Enum.map(fn [_, name] -> String.to_atom(name) end)
  end

  defp find_unused(definitions, references) do
    definitions
    |> Enum.reject(fn %{class: class} -> MapSet.member?(references, class) end)
    |> Enum.group_by(& &1.module)
  end

  defp output_text(unused, definitions) do
    total_count = length(definitions)
    unused_count = unused |> Map.values() |> List.flatten() |> length()

    if unused_count == 0 do
      Mix.shell().info("All #{total_count} class definitions appear to be used.")
    else
      Mix.shell().info(
        "Found #{unused_count} potentially unused classes (out of #{total_count} total):\n"
      )

      for {module, classes} <- Enum.sort(unused) do
        Mix.shell().info("  #{IO.ANSI.bright()}#{module}#{IO.ANSI.reset()}")

        for %{class: class, file: file, line: line} <- Enum.sort_by(classes, & &1.line) do
          Mix.shell().info(
            "    #{IO.ANSI.yellow()}:#{class}#{IO.ANSI.reset()} #{IO.ANSI.faint()}(#{file}:#{line})#{IO.ANSI.reset()}"
          )
        end

        Mix.shell().info("")
      end

      Mix.shell().info(
        "#{IO.ANSI.faint()}Note: Dynamic references may not be detected. Review before removing.#{IO.ANSI.reset()}"
      )
    end
  end

  defp output_json(unused) do
    items =
      unused
      |> Enum.flat_map(fn {module, classes} ->
        Enum.map(classes, fn %{class: class, file: file, line: line} ->
          %{module: module, class: class, file: file, line: line}
        end)
      end)

    Mix.shell().info(Jason.encode!(items))
  end
end
