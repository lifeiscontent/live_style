defmodule LiveStyle.Dev do
  @moduledoc """
  Development helpers for inspecting and debugging LiveStyle classes.

  These functions are designed for use in IEx during development.

  ## Examples

      iex> LiveStyle.Dev.class_info(MyComponent, :button)
      %{
        class: "x1a2b3c4 x5d6e7f8",
        css: "display:flex;padding:8px 16px",
        properties: %{
          "display" => %{class: "x1a2b3c4", value: "flex"},
          "padding" => %{class: "x5d6e7f8", value: "8px 16px"}
        }
      }

      iex> LiveStyle.Dev.list(MyComponent)
      [:button, :primary, :secondary, :disabled]

      iex> LiveStyle.Dev.diff(MyComponent, [:button, :primary])
      # Shows how styles merge with property-level detail

      iex> LiveStyle.Dev.tokens(MyApp.Tokens)
      # Shows all tokens defined in a module
  """

  alias LiveStyle.Manifest

  @doc """
  Returns detailed information about a single class definition.

  Shows generated CSS classes, individual properties, and values.

  ## Examples

      iex> LiveStyle.Dev.class_info(MyComponent, :button)
      %{
        class: "x1a2b3c4 x5d6e7f8",
        css: "display:flex;padding:8px 16px",
        properties: %{
          "display" => %{class: "x1a2b3c4", value: "flex"},
          "padding" => %{class: "x5d6e7f8", value: "8px 16px"}
        }
      }
  """
  def class_info(module, class_name) when is_atom(module) and is_atom(class_name) do
    ensure_live_style_module!(module)

    case LiveStyle.get_metadata(module, {:class, class_name}) do
      nil ->
        {:error, :not_found}

      metadata ->
        class_string = LiveStyle.get_css_class(module, class_name)
        properties = extract_properties(metadata)
        css = build_css_string(properties)

        %{
          name: class_name,
          class: class_string,
          css: css,
          properties: properties,
          dynamic?: match?({:__dynamic__, _, _, _}, metadata[:declaration])
        }
    end
  end

  @doc """
  Lists all class names defined in a module.

  ## Examples

      iex> LiveStyle.Dev.list(MyComponent)
      [:button, :primary, :secondary, :dynamic_opacity]

      iex> LiveStyle.Dev.list(MyComponent, :static)
      [:button, :primary, :secondary]

      iex> LiveStyle.Dev.list(MyComponent, :dynamic)
      [:dynamic_opacity]
  """
  def list(module, filter \\ :all) when is_atom(module) do
    ensure_live_style_module!(module)

    class_strings = module.__live_style__(:class_strings)
    dynamic_names = module.__live_style__(:dynamic_names)

    static_names = Map.keys(class_strings)

    case filter do
      :all -> Enum.sort(static_names ++ dynamic_names)
      :static -> Enum.sort(static_names)
      :dynamic -> Enum.sort(dynamic_names)
    end
  end

  @doc """
  Shows how multiple classes merge, with property-level detail.

  This helps understand which class "wins" for each property when
  composing multiple classes.

  ## Examples

      iex> LiveStyle.Dev.diff(MyComponent, [:button, :primary])
      %{
        merged_class: "x1a2b3c4 x5d6e7f8 x9g0h1i2",
        properties: %{
          "display" => %{value: "flex", from: :button},
          "padding" => %{value: "8px 16px", from: :button},
          "background-color" => %{value: "blue", from: :primary}
        }
      }
  """
  def diff(module, refs) when is_atom(module) and is_list(refs) do
    ensure_live_style_module!(module)

    merged_class = LiveStyle.get_css_class(module, refs)
    property_classes = module.__live_style__(:property_classes)

    # Track which class each property comes from
    properties =
      refs
      |> List.flatten()
      |> Enum.reject(&(&1 == nil or &1 == false))
      |> Enum.reduce(%{}, fn ref, acc ->
        case get_ref_properties(module, ref, property_classes) do
          nil -> acc
          props -> merge_with_source(acc, props, ref)
        end
      end)

    %{
      merged_class: merged_class,
      refs: refs,
      properties: properties
    }
  end

  @doc """
  Shows all tokens (variables, constants, keyframes, themes) defined in a module.

  ## Examples

      iex> LiveStyle.Dev.tokens(MyApp.Tokens)
      %{
        vars: %{
          color: [:primary, :secondary, :white, :black],
          space: [:sm, :md, :lg]
        },
        consts: %{
          breakpoint: [:sm, :md, :lg]
        },
        keyframes: [:spin, :fade_in, :fade_out],
        themes: [{:color, :dark}, {:color, :light}]
      }
  """
  def tokens(module) when is_atom(module) do
    manifest = LiveStyle.Storage.read()

    vars = extract_tokens_by_type(manifest, module, :var)
    consts = extract_tokens_by_type(manifest, module, :const)
    keyframes = extract_tokens_by_type(manifest, module, :keyframes)
    themes = extract_tokens_by_type(manifest, module, :theme)

    %{
      vars: vars,
      consts: consts,
      keyframes: keyframes,
      themes: themes
    }
  end

  @doc """
  Shows the raw CSS output for a class or list of classes.

  ## Examples

      iex> LiveStyle.Dev.css(MyComponent, :button)
      ".x1a2b3c4:not(#\\\\#){display:flex}.x5d6e7f8:not(#\\\\#){padding:8px 16px}"

      iex> LiveStyle.Dev.css(MyComponent, [:button, :primary])
      # Combined CSS for both classes
  """
  def css(module, ref_or_refs) when is_atom(module) do
    ensure_live_style_module!(module)

    refs = List.wrap(ref_or_refs)
    manifest = LiveStyle.Storage.read()

    refs
    |> Enum.flat_map(fn ref ->
      key = Manifest.simple_key(module, ref)

      manifest
      |> Manifest.get_class(key)
      |> extract_ltr_css()
    end)
    |> Enum.join("")
  end

  defp extract_ltr_css(nil), do: []
  defp extract_ltr_css(%{atomic_classes: nil}), do: []

  defp extract_ltr_css(%{atomic_classes: atomic_classes}) when is_map(atomic_classes) do
    atomic_classes
    |> Enum.sort_by(fn {prop, _} -> prop end)
    |> Enum.flat_map(fn {_prop, meta} -> extract_ltr_from_meta(meta) end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_ltr_css(_), do: []

  # Simple property: %{ltr: "...", ...}
  defp extract_ltr_from_meta(%{ltr: ltr}) when is_binary(ltr), do: [ltr]

  # Conditional property: %{classes: %{:default => %{ltr: ...}, ...}}
  defp extract_ltr_from_meta(%{classes: classes}) when is_map(classes) do
    classes
    |> Map.values()
    |> Enum.map(fn
      %{ltr: ltr} when is_binary(ltr) -> ltr
      _ -> nil
    end)
  end

  defp extract_ltr_from_meta(_), do: []

  @doc """
  Prints a formatted summary of a class to the console.

  ## Examples

      iex> LiveStyle.Dev.pp(MyComponent, :button)
      # Prints formatted output
  """
  def pp(module, class_name) when is_atom(module) and is_atom(class_name) do
    case class_info(module, class_name) do
      {:error, :not_found} ->
        IO.puts("Class :#{class_name} not found in #{inspect(module)}")

      info ->
        print_class_info(class_name, info)
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

  @doc """
  Prints a formatted list of all classes in a module.

  ## Examples

      iex> LiveStyle.Dev.pp_list(MyComponent)
      # Prints formatted list
  """
  def pp_list(module) when is_atom(module) do
    ensure_live_style_module!(module)

    static = list(module, :static)
    dynamic = list(module, :dynamic)

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

  # Private helpers

  defp ensure_live_style_module!(module) do
    unless Code.ensure_loaded?(module) and function_exported?(module, :__live_style__, 1) do
      raise ArgumentError, "#{inspect(module)} is not a LiveStyle module"
    end
  end

  defp extract_properties(metadata) do
    case metadata do
      %{atomic_classes: nil} ->
        %{}

      %{atomic_classes: atomic_classes} when is_map(atomic_classes) ->
        atomic_classes
        |> Enum.reject(fn {_prop, meta} -> meta == nil end)
        |> Enum.map(fn {prop, meta} ->
          extract_property_info(prop, meta)
        end)
        |> Enum.reject(&is_nil/1)
        |> Map.new()

      _ ->
        %{}
    end
  end

  # Handle simple property structure: %{class: "x123", value: "red"}
  defp extract_property_info(prop, %{class: class, value: value}) when not is_nil(class) do
    {prop, %{class: class, value: value}}
  end

  # Handle conditional property structure: %{classes: %{:default => %{class: ..., value: ...}, ...}}
  defp extract_property_info(prop, %{classes: classes}) when is_map(classes) do
    # Get the default value, or the first value if no default
    case Map.get(classes, :default) || Map.get(classes, "default") do
      %{class: class, value: value} ->
        # Include info about other variants
        variants =
          classes
          |> Map.keys()
          |> Enum.reject(&(&1 == :default or &1 == "default"))

        {prop, %{class: class, value: value, variants: variants}}

      nil ->
        # No default, get first value
        case Map.values(classes) |> List.first() do
          %{class: class, value: value} ->
            {prop, %{class: class, value: value, conditional: true}}

          _ ->
            nil
        end
    end
  end

  defp extract_property_info(_prop, _meta), do: nil

  defp build_css_string(properties) do
    properties
    |> Enum.sort_by(fn {prop, _} -> prop end)
    |> Enum.map_join(";", fn {prop, %{value: value}} -> "#{prop}:#{value}" end)
  end

  defp get_ref_properties(_module, ref, property_classes) when is_atom(ref) do
    Map.get(property_classes, ref)
  end

  defp get_ref_properties(_module, _ref, _property_classes), do: nil

  defp merge_with_source(acc, props, source_ref) do
    Enum.reduce(props, acc, fn {prop_key, class_name}, inner_acc ->
      # Get the value from metadata
      value = get_property_value(prop_key, class_name)
      Map.put(inner_acc, prop_key, %{value: value, class: class_name, from: source_ref})
    end)
  end

  defp get_property_value(_prop_key, class_name) do
    manifest = LiveStyle.Storage.read()

    # Find the class entry with this atomic class name
    manifest
    |> Map.get(:classes, %{})
    |> Enum.find_value(fn {_key, class_data} ->
      find_value_in_class_data(class_data, class_name)
    end)
  end

  defp find_value_in_class_data(%{atomic_classes: atomic_classes}, class_name)
       when is_map(atomic_classes) do
    Enum.find_value(atomic_classes, fn
      {_prop, %{class: ^class_name, value: value}} ->
        value

      {_prop, %{classes: nested_classes}} when is_map(nested_classes) ->
        # Handle nested structure (e.g., pseudo classes)
        Enum.find_value(nested_classes, fn
          {_variant, %{class: ^class_name, value: value}} -> value
          _ -> nil
        end)

      _ ->
        nil
    end)
  end

  defp find_value_in_class_data(_, _), do: nil

  defp extract_tokens_by_type(manifest, module, type) do
    module_prefix = inspect(module)

    # Map type to manifest key
    manifest_key =
      case type do
        :var -> :vars
        :const -> :consts
        :keyframes -> :keyframes
        :theme -> :themes
      end

    manifest
    |> Map.get(manifest_key, %{})
    |> Enum.filter(fn {key, _data} ->
      String.starts_with?(key, module_prefix)
    end)
    |> Enum.map(fn {key, _data} ->
      parse_token_key(key, module_prefix)
    end)
    |> Enum.reject(&is_nil/1)
    |> group_tokens(type)
  end

  defp parse_token_key(key, module_prefix) do
    # Keys look like "Elixir.MyApp.Tokens.color.primary" or "Elixir.MyApp.Tokens.spin"
    rest = String.replace_prefix(key, module_prefix <> ".", "")

    case String.split(rest, ".") do
      [namespace, name] -> {String.to_atom(namespace), String.to_atom(name)}
      [name] -> String.to_atom(name)
      _ -> nil
    end
  end

  defp group_tokens(tokens, type) when type in [:var, :const] do
    tokens
    |> Enum.group_by(
      fn
        {namespace, _name} -> namespace
        _name -> :default
      end,
      fn
        {_namespace, name} -> name
        name -> name
      end
    )
  end

  defp group_tokens(tokens, _type), do: tokens
end
