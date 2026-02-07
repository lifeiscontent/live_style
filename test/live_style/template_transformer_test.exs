defmodule LiveStyle.TemplateTransformerTest do
  use LiveStyle.TestCase

  defmodule LocalStyles do
    use LiveStyle

    class(:base, color: "#0f172a")
    class(:dynamic_opacity, fn opacity -> [opacity: opacity] end)

    def caller_env, do: __ENV__
  end

  defmodule SharedStyles do
    use LiveStyle

    class(:module_ref,
      display: "inline-flex",
      color: "#1e3a8a"
    )
  end

  describe "transform/2" do
    test "resolves local atom refs in class expression" do
      expected_class = Keyword.fetch!(LocalStyles.__live_style__(:class_strings), :base)
      attrs = transform_attrs("[:base]")

      assert class_ast(attrs) == [expected_class]
      assert style_attr(attrs) == nil
    end

    test "resolves module tuple refs including nested lists" do
      expected_class = Keyword.fetch!(SharedStyles.__live_style__(:class_strings), :module_ref)

      attrs =
        transform_attrs(
          "[{LiveStyle.TemplateTransformerTest.SharedStyles, :module_ref}, [{LiveStyle.TemplateTransformerTest.SharedStyles, :module_ref}]]"
        )

      assert class_ast(attrs) == [expected_class, expected_class]
      assert style_attr(attrs) == nil
    end

    test "inlines static dynamic refs into static class and style attrs" do
      expected = LiveStyle.resolve_attrs(LocalStyles, [{:dynamic_opacity, [opacity: 0.5]}], nil)
      attrs = transform_attrs("[{:dynamic_opacity, opacity: 0.5}]")

      assert class_ast(attrs) == [expected.class]
      assert {"style", {:string, style, %{delimiter: ?"}}, _meta} = style_attr(attrs)
      assert style == expected.style
    end

    test "keeps dynamic style refs as runtime expressions while class stays static" do
      class_name = Keyword.fetch!(LocalStyles.__live_style__(:class_strings), :dynamic_opacity)
      attrs = transform_attrs("[{:dynamic_opacity, opacity: @opacity}]")

      assert class_ast(attrs) == [class_name]
      assert {"style", {:expr, expr, _meta}, _attr_meta} = style_attr(attrs)
      assert expr =~ "LiveStyle.TemplateTransformer.merge_style_segments"
      assert expr =~ "LiveStyle.TemplateTransformer.dynamic_style"
    end
  end

  describe "merge_style_segments/1" do
    test "returns nil when merged style content is blank" do
      assert LiveStyle.TemplateTransformer.merge_style_segments([nil, false, "", "   "]) == nil
    end

    test "returns merged style string when at least one segment is present" do
      assert LiveStyle.TemplateTransformer.merge_style_segments([
               nil,
               "opacity: 0.5",
               [background_color: "#ffffff"]
             ]) == "opacity: 0.5; background-color: #ffffff"
    end
  end

  defp transform_attrs(class_expr, caller_env \\ LocalStyles.caller_env()) do
    parser = %{
      nodes: [
        {:self_close, :tag, "div",
         [{"class", {:expr, class_expr, %{line: 1, column: 1}}, %{line: 1, column: 1}}],
         %{line: 1, column: 1, special: []}}
      ]
    }

    {:ok, %{nodes: [{:self_close, :tag, "div", attrs, _meta}]}} =
      LiveStyle.TemplateTransformer.transform(parser, %{caller: caller_env, file: __ENV__.file})

    attrs
  end

  defp class_ast(attrs) do
    {"class", {:expr, class_expr, class_meta}, _attr_meta} =
      Enum.find(attrs, fn {name, _value, _meta} -> name == "class" end)

    Code.string_to_quoted!(class_expr,
      file: __ENV__.file,
      line: class_meta.line,
      column: class_meta.column
    )
  end

  defp style_attr(attrs) do
    Enum.find(attrs, fn
      {"style", _value, _meta} -> true
      _ -> false
    end)
  end
end
