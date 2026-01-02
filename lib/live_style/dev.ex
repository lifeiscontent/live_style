defmodule LiveStyle.Dev do
  @moduledoc """
  Development helpers for inspecting and debugging LiveStyle classes.

  Note: Functions use `show` instead of `inspect` to avoid conflicts with Kernel.inspect/2.

  This module provides IEx-friendly functions for exploring style definitions,
  understanding how classes merge, and viewing generated CSS.

  ## Usage in IEx

      iex> LiveStyle.Dev.show(MyAppWeb.Button, :primary)
      :primary
      class: x1234 x5678

        background-color: x1234
        color: x5678

      iex> LiveStyle.Dev.diff(MyAppWeb.Button, [:base, :primary])
      :base
        display: x9abc
        padding: xdef0

      :primary
        background-color: x1234
        color: x5678

      Merged:
        class: x9abc xdef0 x1234 x5678

      iex> LiveStyle.Dev.css(MyAppWeb.Button, [:primary])
      ".x1234:not(#\\\\#){background-color:blue}
      .x5678:not(#\\\\#){color:white}"

      iex> LiveStyle.Dev.list(MyAppWeb.Button)
      [:base, :primary, :secondary, :dynamic_opacity]

  ## Note

  These functions read from the compiled manifest. Make sure your modules
  are compiled before using these helpers.
  """

  alias LiveStyle.{Manifest, Storage}

  @doc """
  Lists all class names defined in a module.

  Returns a list of atoms representing the class names.

  ## Example

      iex> LiveStyle.Dev.list(MyAppWeb.Button)
      [:base, :primary, :secondary]
  """
  @spec list(module()) :: [atom()]
  def list(module) do
    ensure_live_style_module!(module)

    module.__live_style__(:class_strings)
    |> Keyword.keys()
  end

  @doc """
  Shows a single class definition, displaying its properties and generated CSS.

  Prints formatted output to the console showing:
  - The generated class string
  - Each CSS property and its atomic class name
  - Whether the class is dynamic

  ## Example

      iex> LiveStyle.Dev.show(MyAppWeb.Button, :primary)
      :primary
      class: x1234 x5678

        background-color: x1234
        color: x5678
  """
  @spec show(module(), atom()) :: :ok
  def show(module, class_name) do
    ensure_live_style_module!(module)

    class_strings = module.__live_style__(:class_strings)
    class_str = Keyword.get(class_strings, class_name, "")

    prop_classes = module.__live_style__(:property_classes)
    props = Keyword.get(prop_classes, class_name, [])

    dynamic_names = module.__live_style__(:dynamic_names)
    is_dynamic = class_name in dynamic_names

    # Header
    IO.puts("")
    IO.puts("#{IO.ANSI.bright()}:#{class_name}#{IO.ANSI.reset()}" <>
            if(is_dynamic, do: " #{IO.ANSI.yellow()}(dynamic)#{IO.ANSI.reset()}", else: ""))
    IO.puts("class: #{if class_str == "", do: "(none)", else: class_str}")
    IO.puts("")

    # Properties
    if props == [] do
      IO.puts("  (no properties)")
    else
      for {prop, class} <- props do
        class_display = format_class_value(class)
        IO.puts("  #{prop}: #{class_display}")
      end
    end

    IO.puts("")
    :ok
  end

  @doc """
  Shows what each class contributes and the merged result.

  Useful for understanding how multiple classes combine and which
  properties override others.

  ## Example

      iex> LiveStyle.Dev.diff(MyAppWeb.Button, [:base, :primary])
      :base
        display: x9abc
        padding: xdef0

      :primary
        background-color: x1234
        color: x5678

      Merged:
        class: x9abc xdef0 x1234 x5678
  """
  @spec diff(module(), [atom() | {atom(), any()}]) :: :ok
  def diff(module, class_refs) when is_list(class_refs) do
    ensure_live_style_module!(module)

    prop_classes = module.__live_style__(:property_classes)

    IO.puts("")

    # Show each class's contribution
    for ref <- class_refs do
      name = if is_tuple(ref), do: elem(ref, 0), else: ref
      props = Keyword.get(prop_classes, name, [])

      IO.puts("#{IO.ANSI.cyan()}:#{name}#{IO.ANSI.reset()}")
      if props == [] do
        IO.puts("  (no properties)")
      else
        for {prop, class} <- props do
          class_display = format_class_value(class)
          IO.puts("  #{prop}: #{class_display}")
        end
      end
      IO.puts("")
    end

    # Show merged result
    attrs = LiveStyle.resolve_attrs(module, class_refs, nil)

    IO.puts("#{IO.ANSI.bright()}Merged:#{IO.ANSI.reset()}")
    IO.puts("  class: #{attrs.class || "(none)"}")
    if attrs.style do
      IO.puts("  style: #{attrs.style}")
    end
    IO.puts("")

    :ok
  end

  @doc """
  Returns the generated CSS for the given classes.

  Returns the raw CSS rules as a string, useful for debugging
  what CSS is actually generated for your styles.

  ## Example

      iex> LiveStyle.Dev.css(MyAppWeb.Button, [:primary])
      ".x1234:not(#\\\\#){background-color:blue}
      .x5678:not(#\\\\#){color:white}"
  """
  @spec css(module(), [atom()]) :: String.t()
  def css(module, class_atoms) when is_list(class_atoms) do
    ensure_live_style_module!(module)

    manifest = Storage.read()

    class_atoms
    |> Enum.flat_map(fn name ->
      key = Manifest.key(module, name)

      case Manifest.get_class(manifest, key) do
        nil ->
          []

        entry ->
          entry
          |> Keyword.fetch!(:atomic_classes)
          |> Enum.flat_map(fn {_prop, data} ->
            extract_css_rules(data)
          end)
      end
    end)
    |> Enum.uniq()
    |> Enum.join("\n")
  end

  @doc """
  Pretty-prints a class to the console.

  Alias for `show/2` for convenience.
  """
  @spec pp(module(), atom()) :: :ok
  def pp(module, class_name), do: show(module, class_name)

  # Private helpers

  defp ensure_live_style_module!(module) do
    unless Code.ensure_loaded?(module) do
      raise ArgumentError, "Module #{Elixir.Kernel.inspect(module)} is not loaded"
    end

    unless function_exported?(module, :__live_style__, 1) do
      raise ArgumentError,
            "Module #{Elixir.Kernel.inspect(module)} is not a LiveStyle module. " <>
              "Make sure it uses `use LiveStyle`."
    end
  end

  defp format_class_value(:__unset__), do: "(unset)"
  defp format_class_value(class) when is_binary(class), do: class
  defp format_class_value(other), do: Elixir.Kernel.inspect(other)

  # Extract CSS rules from atomic class data
  # Simple entry: [class: "x123", priority: 4000, ltr: "...", rtl: nil]
  defp extract_css_rules(data) when is_list(data) do
    # Check if this is a conditional entry with :classes wrapper
    case Keyword.get(data, :classes) do
      nil ->
        # Simple entry - extract ltr/rtl directly
        extract_ltr_rtl(data)

      classes when is_list(classes) ->
        # Conditional entry - recurse into each condition
        Enum.flat_map(classes, fn {_condition, entry} ->
          extract_ltr_rtl(entry)
        end)
    end
  end

  defp extract_css_rules(_), do: []

  defp extract_ltr_rtl(entry) when is_list(entry) do
    ltr = Keyword.get(entry, :ltr)
    rtl = Keyword.get(entry, :rtl)

    rules = []
    rules = if ltr && ltr != "", do: [ltr | rules], else: rules
    rules = if rtl && rtl != "", do: [rtl | rules], else: rules
    Enum.reverse(rules)
  end

  defp extract_ltr_rtl(_), do: []
end
