defmodule LiveStyle.TemplateTransformer do
  @moduledoc """
  HEEx transformer that resolves LiveStyle refs in `class={...}` expressions.

  Configure it in your app:

      config :phoenix_live_view, :template_transformers, [
        LiveStyle.TemplateTransformer
      ]

  This module is external to `phoenix_live_view`, so it composes with other
  transformer modules by ordering them in `:template_transformers`.
  """

  alias LiveStyle.Compiler.BeforeCompile
  alias LiveStyle.Runtime.Dynamic

  @doc false
  def dynamic_class(module, name, args)
      when is_atom(module) and is_atom(name) do
    %LiveStyle.Attrs{class: class} = dynamic_attrs(module, name, args)
    class
  end

  def dynamic_class(_module, _name, _args), do: ""

  @doc false
  def dynamic_style(module, name, args)
      when is_atom(module) and is_atom(name) do
    case dynamic_attrs(module, name, args) do
      %LiveStyle.Attrs{style: style} when is_binary(style) and style != "" -> style
      _ -> nil
    end
  end

  def dynamic_style(_module, _name, _args), do: nil

  @doc false
  def merge_style_segments(segments) when is_list(segments) do
    merged =
      segments
      |> Enum.flat_map(&normalize_style_segment/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("; ")

    if merged == "", do: nil, else: merged
  end

  def merge_style_segments(segment), do: merge_style_segments([segment])

  defp normalize_style_segment(nil), do: []
  defp normalize_style_segment(false), do: []
  defp normalize_style_segment(true), do: []

  defp normalize_style_segment(%LiveStyle.Attrs{style: style}) do
    normalize_style_segment(style)
  end

  defp normalize_style_segment(segment) when is_binary(segment), do: [segment]

  defp normalize_style_segment(segment) when is_list(segment) do
    if Keyword.keyword?(segment) do
      [keyword_style_to_string(segment)]
    else
      Enum.flat_map(segment, &normalize_style_segment/1)
    end
  end

  defp normalize_style_segment(segment), do: [to_string(segment)]

  defp keyword_style_to_string(keyword) do
    keyword
    |> Enum.flat_map(fn
      {_key, nil} -> []
      {_key, false} -> []
      {_key, true} -> []
      {key, value} -> ["#{style_key(key)}: #{style_value(value)}"]
      _ -> []
    end)
    |> Enum.join("; ")
  end

  defp style_key(key) when is_atom(key), do: LiveStyle.CSSValue.to_css_property(key)
  defp style_key(key) when is_binary(key), do: key
  defp style_key(key), do: to_string(key)

  defp style_value(value) when is_binary(value), do: value
  defp style_value(value), do: to_string(value)

  def transform(%{nodes: nodes} = parser, %{caller: %Macro.Env{} = caller, file: file})
      when is_list(nodes) and is_binary(file) do
    context = %{
      caller: caller,
      caller_module: caller.module,
      file: file,
      class_cache: %{},
      open_module_data: %{}
    }

    {nodes, _context} = rewrite_nodes(nodes, context)
    {:ok, %{parser | nodes: nodes}}
  end

  def transform(_parser, _context), do: :noop

  defp rewrite_nodes(nodes, context) do
    Enum.map_reduce(nodes, context, &rewrite_node/2)
  end

  defp rewrite_node({:self_close, type, name, attrs, meta}, context) do
    {attrs, context} = rewrite_attrs(attrs, context)
    {{:self_close, type, name, attrs, meta}, context}
  end

  defp rewrite_node({:block, type, name, attrs, children, meta, close_meta}, context) do
    {attrs, context} = rewrite_attrs(attrs, context)
    {children, context} = rewrite_nodes(children, context)
    {{:block, type, name, attrs, children, meta, close_meta}, context}
  end

  defp rewrite_node({:eex_block, expr, blocks, meta}, context) do
    {blocks, context} =
      Enum.map_reduce(blocks, context, fn {children, clause_expr, clause_meta}, context ->
        {children, context} = rewrite_nodes(children, context)
        {{children, clause_expr, clause_meta}, context}
      end)

    {{:eex_block, expr, blocks, meta}, context}
  end

  defp rewrite_node(node, context), do: {node, context}

  defp rewrite_attrs(attrs, context) do
    case find_class_expr_attr(attrs) do
      {:ok, index, {"class", {:expr, expr, expr_meta}, attr_meta}} ->
        {expr, style_parts, context} = rewrite_class_expr(expr, expr_meta, context)
        class_attr = {"class", {:expr, expr, expr_meta}, attr_meta}
        attrs = List.replace_at(attrs, index, class_attr)
        merge_dynamic_style_attr(attrs, style_parts, expr_meta, attr_meta, context)

      _ ->
        {attrs, context}
    end
  end

  defp find_class_expr_attr(attrs) do
    attrs
    |> Enum.with_index()
    |> Enum.find_value(:error, fn
      {{"class", {:expr, _expr, _expr_meta}, _attr_meta} = attr, index} -> {:ok, index, attr}
      _ -> false
    end)
  end

  defp rewrite_class_expr(expr, meta, %{file: file} = context) do
    case quoted_from_string(expr, meta, file) do
      {:ok, ast} ->
        {rewritten, style_parts, context} = rewrite_class_ast(ast, context)
        rewritten = maybe_flatten_literal_class_list(rewritten)

        expr =
          if rewritten == ast do
            expr
          else
            Macro.to_string(rewritten)
          end

        {expr, style_parts, context}

      :error ->
        {expr, [], context}
    end
  end

  defp maybe_flatten_literal_class_list(list) when is_list(list) do
    if Keyword.keyword?(list) do
      list
    else
      flatten_literal_class_list(list)
    end
  end

  defp maybe_flatten_literal_class_list(other), do: other

  defp flatten_literal_class_list(list) do
    Enum.flat_map(list, fn
      inner when is_list(inner) ->
        if Keyword.keyword?(inner) do
          [inner]
        else
          flatten_literal_class_list(inner)
        end

      other ->
        [other]
    end)
  end

  defp rewrite_class_ast({module_ast, name, args_ast} = tuple, context) when is_atom(name) do
    case expand_module(module_ast, context.caller) do
      module when is_atom(module) ->
        rewrite_dynamic_ref(module, name, args_ast, tuple, context)

      _ ->
        {tuple, [], context}
    end
  end

  # Legacy dynamic tuple style: {{Module, :name}, args}
  defp rewrite_class_ast({{module_ast, name}, args_ast} = tuple, context) when is_atom(name) do
    case expand_module(module_ast, context.caller) do
      module when is_atom(module) ->
        rewrite_dynamic_ref(module, name, args_ast, tuple, context)

      _ ->
        {tuple, [], context}
    end
  end

  defp rewrite_class_ast({module_ast, name} = tuple, context) when is_atom(name) do
    case expand_module(module_ast, context.caller) do
      module when is_atom(module) ->
        case lookup_class(module, name, context) do
          {class_name, context} when is_binary(class_name) ->
            record_usage(context.caller_module, module, name)
            {class_name, [], context}

          {nil, context} ->
            {tuple, [], context}
        end

      _ ->
        {tuple, [], context}
    end
  end

  defp rewrite_class_ast({name, args_ast} = tuple, context) when is_atom(name) do
    if class_name_atom?(name) and dynamic_ref_args?(args_ast) and
         is_atom(context.caller_module) do
      rewrite_dynamic_ref(context.caller_module, name, args_ast, tuple, context)
    else
      {tuple, [], context}
    end
  end

  defp rewrite_class_ast(atom, context) when is_atom(atom) do
    if class_name_atom?(atom) and is_atom(context.caller_module) do
      case lookup_class(context.caller_module, atom, context) do
        {class_name, context} when is_binary(class_name) ->
          record_usage(context.caller_module, context.caller_module, atom)
          {class_name, [], context}

        {nil, context} ->
          {atom, [], context}
      end
    else
      {atom, [], context}
    end
  end

  defp rewrite_class_ast({:__aliases__, _, _} = alias_ast, context), do: {alias_ast, [], context}

  # 3-element tuple literal AST: {Module, :dynamic_name, args}
  defp rewrite_class_ast({:{}, _meta, [module_ast, name, args_ast]} = tuple_ast, context)
       when is_atom(name) do
    case expand_module(module_ast, context.caller) do
      module when is_atom(module) ->
        rewrite_dynamic_ref(module, name, args_ast, tuple_ast, context)

      _ ->
        {tuple_ast, [], context}
    end
  end

  defp rewrite_class_ast({form, meta, args}, context) when is_atom(form) and is_list(args) do
    {args, style_parts, context} = rewrite_ast_items(args, context)
    {{form, meta, args}, style_parts, context}
  end

  defp rewrite_class_ast(list, context) when is_list(list) do
    if Keyword.keyword?(list) do
      rewrite_keyword_dynamic_list(list, context)
    else
      rewrite_ast_items(list, context)
    end
  end

  defp rewrite_class_ast(tuple, context) when is_tuple(tuple) do
    {list, style_parts, context} =
      tuple
      |> Tuple.to_list()
      |> rewrite_ast_items(context)

    {List.to_tuple(list), style_parts, context}
  end

  defp rewrite_class_ast(other, context), do: {other, [], context}

  defp rewrite_keyword_dynamic_list(keyword_list, context) do
    {items, style_parts_lists, context} =
      Enum.reduce(keyword_list, {[], [], context}, fn
        {name, args}, {items_acc, styles_acc, context}
        when is_atom(name) and is_list(args) and is_atom(context.caller_module) ->
          {class_ast, style_parts, context} =
            rewrite_dynamic_ref(context.caller_module, name, args, {name, args}, context)

          {[class_ast | items_acc], [style_parts | styles_acc], context}

        {{module_ast, name}, args}, {items_acc, styles_acc, context}
        when is_atom(name) and is_list(args) ->
          case expand_module(module_ast, context.caller) do
            module when is_atom(module) ->
              {class_ast, style_parts, context} =
                rewrite_dynamic_ref(module, name, args, {{module_ast, name}, args}, context)

              {[class_ast | items_acc], [style_parts | styles_acc], context}

            _ ->
              {[{{module_ast, name}, args} | items_acc], [[] | styles_acc], context}
          end

        entry, {items_acc, styles_acc, context} ->
          {[entry | items_acc], [[] | styles_acc], context}
      end)

    {Enum.reverse(items), style_parts_lists |> Enum.reverse() |> List.flatten(), context}
  end

  defp rewrite_ast_items(items, context) when is_list(items) do
    {items, style_parts_lists, context} =
      Enum.reduce(items, {[], [], context}, fn item, {items_acc, styles_acc, context} ->
        {item, item_styles, context} = rewrite_class_ast(item, context)
        {[item | items_acc], [item_styles | styles_acc], context}
      end)

    {Enum.reverse(items), style_parts_lists |> Enum.reverse() |> List.flatten(), context}
  end

  defp rewrite_dynamic_ref(module, name, args_ast, _tuple, context) do
    record_usage(context.caller_module, module, name)

    {class_name, context} = dynamic_class_name(module, name, context)

    if Macro.quoted_literal?(args_ast) do
      case resolve_dynamic_literal(module, name, args_ast, context) do
        {attrs, context} when is_map(attrs) ->
          class_ast =
            class_name || Map.get(attrs, :class) ||
              runtime_dynamic_class_ast(module, name, args_ast)

          style_parts = style_parts_from_attrs(attrs)
          {class_ast, style_parts, context}

        {nil, context} ->
          class_ast = class_name || runtime_dynamic_class_ast(module, name, args_ast)
          style_ast = runtime_dynamic_style_ast(module, name, args_ast)
          {class_ast, [{:dynamic, style_ast}], context}
      end
    else
      if class_name do
        style_ast = runtime_dynamic_style_ast(module, name, args_ast)
        {class_name, [{:dynamic, style_ast}], context}
      else
        class_ast = runtime_dynamic_class_ast(module, name, args_ast)
        style_ast = runtime_dynamic_style_ast(module, name, args_ast)
        {class_ast, [{:dynamic, style_ast}], context}
      end
    end
  rescue
    _ ->
      class_ast = runtime_dynamic_class_ast(module, name, args_ast)
      style_ast = runtime_dynamic_style_ast(module, name, args_ast)
      {class_ast, [{:dynamic, style_ast}], context}
  end

  defp dynamic_ref_args?(args) when is_list(args), do: true
  defp dynamic_ref_args?(_), do: false

  defp runtime_dynamic_class_ast(module, name, args_ast) do
    quote do
      LiveStyle.TemplateTransformer.dynamic_class(
        unquote(module),
        unquote(name),
        unquote(args_ast)
      )
    end
  end

  defp runtime_dynamic_style_ast(module, name, args_ast) do
    quote do
      LiveStyle.TemplateTransformer.dynamic_style(
        unquote(module),
        unquote(name),
        unquote(args_ast)
      )
    end
  end

  defp style_parts_from_attrs(%{style: style}) when is_binary(style) and style != "" do
    [{:static, style}]
  end

  defp style_parts_from_attrs(_), do: []

  defp resolve_dynamic_literal(module, name, args, context)
       when is_atom(module) and is_atom(name) do
    case resolve_dynamic_loaded(module, name, args) do
      attrs when is_map(attrs) ->
        {attrs, context}

      nil ->
        resolve_dynamic_open(module, name, args, context)
    end
  end

  defp resolve_dynamic_literal(_module, _name, _args, context), do: {nil, context}

  defp resolve_dynamic_loaded(module, name, args)
       when is_atom(module) and is_atom(name) do
    case dynamic_loaded?(module, name) do
      true ->
        case LiveStyle.resolve_attrs(module, [{name, args}], nil) do
          %LiveStyle.Attrs{class: class, style: style}
          when is_binary(class) and class != "" ->
            %{class: class, style: style}

          _ ->
            nil
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp resolve_dynamic_loaded(_module, _name, _args), do: nil

  defp resolve_dynamic_open(module, name, args, context)
       when is_atom(module) and is_atom(name) do
    if module_open_with_live_style_attrs?(module) do
      {open_data, context} = open_module_data(module, context)

      with %{all_props: all_props, has_computed: false} <- Map.get(open_data.dynamic, name),
           class_name when is_binary(class_name) and class_name != "" <-
             Keyword.get(open_data.class_strings, name),
           values when is_list(values) <- normalize_dynamic_args(args, all_props),
           var_list when is_list(var_list) <-
             Dynamic.compute_var_list(all_props, values, module, name, false) do
        {%{class: class_name, style: format_var_style(var_list)}, context}
      else
        _ -> {nil, context}
      end
    else
      {nil, context}
    end
  rescue
    _ -> {nil, context}
  end

  defp resolve_dynamic_open(_module, _name, _args, context), do: {nil, context}

  defp dynamic_class_name(module, name, context) when is_atom(module) and is_atom(name) do
    case dynamic_loaded?(module, name) do
      true ->
        class_name = module.__live_style__(:class_strings) |> Keyword.get(name)
        {blank_to_nil(class_name), context}

      _ ->
        dynamic_class_name_from_open_module(module, name, context)
    end
  rescue
    _ -> {nil, context}
  end

  defp dynamic_class_name(_module, _name, context), do: {nil, context}

  defp dynamic_class_name_from_open_module(module, name, context) do
    case module_open_with_live_style_attrs?(module) do
      true ->
        {open_data, context} = open_module_data(module, context)
        class_name = open_dynamic_class_name(open_data, name)
        {blank_to_nil(class_name), context}

      _ ->
        {nil, context}
    end
  end

  defp open_dynamic_class_name(open_data, name) do
    case Map.has_key?(open_data.dynamic, name) do
      true -> Keyword.get(open_data.class_strings, name)
      _ -> nil
    end
  end

  defp dynamic_loaded?(module, name) do
    function_exported?(module, :__live_style__, 1) and
      name in (module.__live_style__(:dynamic_names) || [])
  rescue
    _ -> false
  end

  defp normalize_dynamic_args(args, all_props)
       when is_list(args) and is_list(all_props) and all_props != [] do
    if Keyword.keyword?(args) do
      Enum.map(all_props, &Keyword.get(args, &1))
    else
      args
    end
  end

  defp normalize_dynamic_args(args, _all_props), do: args

  defp format_var_style(var_list) do
    style =
      var_list
      |> List.wrap()
      |> Enum.map_join("; ", fn {var_name, value} -> "#{var_name}: #{value}" end)

    if style == "", do: nil, else: style
  end

  defp merge_dynamic_style_attr(attrs, style_parts, class_expr_meta, class_attr_meta, context) do
    style_parts = normalize_style_parts(style_parts)

    if style_parts == [] do
      {attrs, context}
    else
      merge_or_append_style_attr(attrs, style_parts, class_expr_meta, class_attr_meta, context)
    end
  end

  defp merge_or_append_style_attr(attrs, style_parts, class_expr_meta, class_attr_meta, context) do
    case find_style_attr(attrs) do
      {:ok, index, style_attr} ->
        {existing_part, context} = style_attr_part(style_attr, context)
        style_parts = prepend_existing_style_part(style_parts, existing_part)

        style_attr =
          build_style_attr(
            style_parts,
            style_expr_meta(style_attr, class_expr_meta, class_attr_meta),
            style_attr_meta(style_attr, class_attr_meta)
          )

        {put_or_delete_style_attr(attrs, index, style_attr), context}

      :error ->
        style_attr =
          build_style_attr(
            style_parts,
            style_expr_meta(nil, class_expr_meta, class_attr_meta),
            style_attr_meta(nil, class_attr_meta)
          )

        {append_style_attr(attrs, style_attr), context}
    end
  end

  defp prepend_existing_style_part(style_parts, nil), do: style_parts
  defp prepend_existing_style_part(style_parts, existing_part), do: [existing_part | style_parts]

  defp put_or_delete_style_attr(attrs, index, nil), do: List.delete_at(attrs, index)

  defp put_or_delete_style_attr(attrs, index, style_attr),
    do: List.replace_at(attrs, index, style_attr)

  defp append_style_attr(attrs, nil), do: attrs
  defp append_style_attr(attrs, style_attr), do: attrs ++ [style_attr]

  defp normalize_style_parts(style_parts) do
    Enum.flat_map(style_parts, fn
      {:static, value} when is_binary(value) and value != "" ->
        [
          {:static, value}
        ]

      {:dynamic, _ast} = part ->
        [part]

      _ ->
        []
    end)
  end

  defp find_style_attr(attrs) do
    attrs
    |> Enum.with_index()
    |> Enum.find_value(:error, fn
      {{"style", _value, _meta} = attr, index} -> {:ok, index, attr}
      _ -> false
    end)
  end

  defp style_attr_part({"style", {:string, value, _value_meta}, _attr_meta}, context)
       when is_binary(value) do
    {{:static, value}, context}
  end

  defp style_attr_part({"style", {:expr, expr, expr_meta}, _attr_meta}, context)
       when is_binary(expr) do
    case quoted_from_string(expr, expr_meta, context.file) do
      {:ok, ast} ->
        {{:dynamic, ast}, context}

      :error ->
        {{:static, expr}, context}
    end
  end

  defp style_attr_part(_style_attr, context), do: {nil, context}

  defp build_style_attr(style_parts, expr_meta, attr_meta) do
    if Enum.all?(style_parts, fn {kind, _} -> kind == :static end) do
      style =
        style_parts
        |> Enum.map(fn {:static, value} -> value end)
        |> merge_style_segments()

      if is_binary(style) and style != "" do
        {"style", {:string, style, %{delimiter: ?"}}, attr_meta}
      end
    else
      segments =
        Enum.map(style_parts, fn
          {:static, value} -> value
          {:dynamic, ast} -> ast
        end)

      expr_ast =
        quote do
          LiveStyle.TemplateTransformer.merge_style_segments(unquote(segments))
        end

      {"style", {:expr, Macro.to_string(expr_ast), expr_meta}, attr_meta}
    end
  end

  defp style_expr_meta(
         {"style", {:expr, _expr, expr_meta}, _attr_meta},
         _class_expr_meta,
         _class_attr_meta
       ),
       do: normalize_expr_meta(expr_meta)

  defp style_expr_meta(_style_attr, class_expr_meta, class_attr_meta) do
    class_expr_meta
    |> normalize_expr_meta()
    |> Map.put_new(:line, Map.get(class_attr_meta, :line, 1))
    |> Map.put_new(:column, Map.get(class_attr_meta, :column, 1))
  end

  defp style_attr_meta({"style", _value, attr_meta}, _class_attr_meta), do: attr_meta
  defp style_attr_meta(_style_attr, class_attr_meta), do: class_attr_meta

  defp normalize_expr_meta(meta) when is_map(meta) do
    %{line: Map.get(meta, :line, 1), column: Map.get(meta, :column, 1)}
  end

  defp normalize_expr_meta(_meta), do: %{line: 1, column: 1}

  defp quoted_from_string(expr, meta, file) when is_binary(expr) do
    line = Map.get(meta, :line, 1)
    column = Map.get(meta, :column, 1)

    case Code.string_to_quoted(expr, line: line, column: column, file: file) do
      {:ok, ast} -> {:ok, ast}
      {:error, _} -> :error
    end
  end

  defp quoted_from_string(_expr, _meta, _file), do: :error

  defp dynamic_attrs(module, name, args) do
    LiveStyle.resolve_attrs(module, [{name, args}], nil)
  rescue
    _ -> %LiveStyle.Attrs{class: "", style: nil}
  end

  defp lookup_class(module, class_name, %{class_cache: class_cache} = context) do
    key = {module, class_name}

    case class_cache do
      %{^key => :missing} ->
        {nil, context}

      %{^key => class_name} when is_binary(class_name) ->
        {class_name, context}

      _ ->
        {resolved, context} = resolve_class(module, class_name, context)

        class_cache =
          Map.put(
            context.class_cache,
            key,
            if(is_binary(resolved), do: resolved, else: :missing)
          )

        {resolved, %{context | class_cache: class_cache}}
    end
  end

  defp resolve_class(module, class_name, context) do
    case class_from_module(module, class_name) do
      class_name when is_binary(class_name) ->
        {class_name, context}

      nil ->
        case class_from_open_module(module, class_name, context) do
          {class_name, context} when is_binary(class_name) -> {class_name, context}
          {nil, context} -> {class_from_manifest(module, class_name), context}
        end
    end
  end

  defp class_from_module(module, class_name) when is_atom(module) and is_atom(class_name) do
    if function_exported?(module, :__live_style__, 1) do
      class_strings =
        try do
          module.__live_style__(:class_strings)
        rescue
          _ -> []
        catch
          _, _ -> []
        end

      case Keyword.fetch(class_strings, class_name) do
        {:ok, class_name} when is_binary(class_name) and class_name != "" -> class_name
        _ -> nil
      end
    end
  end

  defp class_from_module(_module, _class_name), do: nil

  defp class_from_open_module(module, class_name, context)
       when is_atom(module) and is_atom(class_name) do
    if module_open_with_live_style_attrs?(module) do
      {open_data, context} = open_module_data(module, context)

      case Keyword.fetch(open_data.class_strings, class_name) do
        {:ok, class_name} when is_binary(class_name) and class_name != "" -> {class_name, context}
        _ -> {nil, context}
      end
    else
      {nil, context}
    end
  end

  defp class_from_open_module(_module, _class_name, context), do: {nil, context}

  defp open_module_data(module, %{open_module_data: cache} = context) do
    case cache do
      %{^module => data} ->
        {data, context}

      _ ->
        data = build_open_module_data(module)
        cache = Map.put(cache, module, data)
        {data, %{context | open_module_data: cache}}
    end
  end

  defp build_open_module_data(module) when is_atom(module) do
    classes = Module.get_attribute(module, :__live_style_classes__) || []
    classes = Enum.reverse(classes)

    {static_classes, dynamic_classes} =
      Enum.split_with(classes, fn
        {_name, {:__dynamic__, _, _}} -> false
        _ -> true
      end)

    manifest =
      Enum.reduce(static_classes, LiveStyle.Manifest.empty(), fn class_entry, manifest ->
        {name, declarations, opts} = BeforeCompile.normalize_class_entry(class_entry)
        LiveStyle.Class.batch_define(manifest, module, name, declarations, opts)
      end)

    manifest =
      Enum.reduce(dynamic_classes, manifest, fn
        {name, {:__dynamic__, all_props, _has_computed}}, manifest ->
          LiveStyle.Class.batch_define_dynamic(manifest, module, name, all_props)

        _entry, manifest ->
          manifest
      end)

    {class_strings, _property_classes} = BeforeCompile.build_class_maps(classes, module, manifest)

    dynamic =
      Enum.reduce(dynamic_classes, %{}, fn
        {name, {:__dynamic__, all_props, has_computed}}, acc ->
          Map.put(acc, name, %{all_props: all_props, has_computed: has_computed})

        {name, {:__dynamic__, all_props}}, acc ->
          Map.put(acc, name, %{all_props: all_props, has_computed: false})

        _, acc ->
          acc
      end)

    %{class_strings: class_strings, dynamic: dynamic}
  rescue
    _ -> %{class_strings: [], dynamic: %{}}
  end

  defp class_from_manifest(module, class_name) when is_atom(module) and is_atom(class_name) do
    key = Atom.to_string(module) <> "." <> Atom.to_string(class_name)

    with manifest when is_map(manifest) <- LiveStyle.Storage.read(),
         classes when is_list(classes) <- Map.get(manifest, :classes, []),
         {^key, entry} <- List.keyfind(classes, key, 0),
         class_name when is_binary(class_name) and class_name != "" <-
           Keyword.get(entry, :class_string) do
      class_name
    else
      _ -> nil
    end
  end

  defp class_name_atom?(nil), do: false
  defp class_name_atom?(false), do: false
  defp class_name_atom?(true), do: false

  defp class_name_atom?(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.match?(~r/^[a-z_][a-zA-Z0-9_]*$/)
  end

  defp module_open_with_live_style_attrs?(module) when is_atom(module) do
    Module.open?(module) and Module.has_attribute?(module, :__live_style_classes__)
  rescue
    _ -> false
  end

  defp expand_module({:__aliases__, _, _} = module_ast, %Macro.Env{} = caller),
    do: Macro.expand(module_ast, caller)

  defp expand_module(module, _caller) when is_atom(module), do: module
  defp expand_module(_module_ast, _caller), do: nil

  defp record_usage(consuming_module, defining_module, class_name)
       when is_atom(consuming_module) and is_atom(defining_module) and is_atom(class_name) do
    LiveStyle.record_class_usage(consuming_module, defining_module, class_name)
  rescue
    _ -> :ok
  end

  defp record_usage(_consuming_module, _defining_module, _class_name), do: :ok

  defp blank_to_nil(value) when is_binary(value) and value != "", do: value
  defp blank_to_nil(_), do: nil
end
