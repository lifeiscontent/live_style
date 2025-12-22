defmodule LiveStyle.Dev.Pretty do
  @moduledoc false

  alias LiveStyle.Dev.ClassInfo
  alias LiveStyle.Dev.List

  @spec pp(module(), atom()) :: :ok
  def pp(module, class_name) when is_atom(module) and is_atom(class_name) do
    case ClassInfo.class_info(module, class_name) do
      {:error, :not_found} ->
        IO.puts("Class :#{class_name} not found in #{inspect(module)}")

      info ->
        print_class_info(class_name, info)
    end

    :ok
  end

  @spec pp_list(module()) :: :ok
  def pp_list(module) when is_atom(module) do
    static = List.list(module, :static)
    dynamic = List.list(module, :dynamic)

    IO.puts("")
    IO.puts("  #{IO.ANSI.bright()}#{inspect(module)}#{IO.ANSI.reset()}")
    IO.puts("")

    if static != [] do
      IO.puts("  #{IO.ANSI.faint()}Static classes:#{IO.ANSI.reset()}")

      Enum.each(static, fn name ->
        class_string = LiveStyle.get_css_class(module, name)
        IO.puts("    :#{name} #{IO.ANSI.faint()}→ #{class_string}#{IO.ANSI.reset()}")
      end)

      IO.puts("")
    end

    if dynamic != [] do
      IO.puts("  #{IO.ANSI.faint()}Dynamic classes:#{IO.ANSI.reset()}")

      Enum.each(dynamic, fn name ->
        IO.puts("    :#{name} #{IO.ANSI.yellow()}(fn)#{IO.ANSI.reset()}")
      end)

      IO.puts("")
    end

    :ok
  end

  defp print_class_info(class_name, info) do
    IO.puts("")
    IO.puts("  #{IO.ANSI.bright()}:#{class_name}#{IO.ANSI.reset()}")
    IO.puts("  #{IO.ANSI.faint()}class: #{info.class}#{IO.ANSI.reset()}")
    IO.puts("")

    if info.dynamic? do
      IO.puts("  #{IO.ANSI.yellow()}(dynamic)#{IO.ANSI.reset()}")
    else
      print_properties(info.properties)
    end

    IO.puts("")
  end

  defp print_properties(properties) do
    properties
    |> Enum.sort_by(fn {prop, _} -> prop end)
    |> Enum.each(fn {prop, %{class: class, value: value}} ->
      IO.puts(
        "  #{IO.ANSI.cyan()}#{prop}#{IO.ANSI.reset()}: #{value} #{IO.ANSI.faint()}(#{class})#{IO.ANSI.reset()}"
      )
    end)
  end
end
