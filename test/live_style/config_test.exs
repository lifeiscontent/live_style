defmodule LiveStyle.ConfigTest do
  @moduledoc """
  Tests for compile-time configuration.

  These tests verify that config values are properly read at compile time.
  To test different config values, you would need to set them in config/test.exs
  and recompile.
  """
  use LiveStyle.TestCase

  alias LiveStyle.Config

  describe "class_name_prefix" do
    test "returns configured prefix" do
      # Default is "x"
      assert Config.class_name_prefix() == "x"
    end

    test "prefix is used in generated class names" do
      css = LiveStyle.Compiler.generate_css()
      # All class names should start with the prefix
      assert css =~ ~r/\.x[a-z0-9]+\{/
    end
  end

  describe "debug_class_names?" do
    test "returns configured value" do
      # Default is false
      assert Config.debug_class_names?() == false
    end
  end

  describe "use_css_layers?" do
    test "returns configured value" do
      # Default is false
      assert Config.use_css_layers?() == false
    end

    test "when false, uses :not(#\\#) selector hack" do
      css = LiveStyle.Compiler.generate_css()
      # Should use the selector hack for specificity when layers are disabled
      if not Config.use_css_layers?() do
        assert css =~ ":not(#\\#)"
      end
    end
  end

  describe "font_size_px_to_rem?" do
    test "returns configured value" do
      # Default is false
      assert Config.font_size_px_to_rem?() == false
    end
  end

  describe "font_size_root_px" do
    test "returns configured value" do
      # Default is 16
      assert Config.font_size_root_px() == 16
    end
  end

  describe "shorthand_behavior" do
    test "returns tuple of {module, opts}" do
      {module, opts} = Config.shorthand_behavior()
      assert is_atom(module)
      assert is_list(opts)
    end

    test "default behavior is AcceptShorthands" do
      {module, _opts} = Config.shorthand_behavior()
      assert module == LiveStyle.ShorthandBehavior.AcceptShorthands
    end
  end

  describe "validation config" do
    test "validate_properties? returns boolean" do
      assert is_boolean(Config.validate_properties?())
    end

    test "unknown_property_level returns atom" do
      level = Config.unknown_property_level()
      assert level in [:warn, :error, :ignore]
    end

    test "vendor_prefix_level returns atom" do
      level = Config.vendor_prefix_level()
      assert level in [:warn, :ignore]
    end

    test "deprecated_property_level returns atom" do
      level = Config.deprecated_property_level()
      assert level in [:warn, :ignore]
    end
  end

  describe "prefix_css" do
    test "returns nil by default" do
      assert Config.prefix_css() == nil
    end

    test "apply_prefix_css returns property:value when no prefix_css configured" do
      result = Config.apply_prefix_css("color", "red")
      assert result == "color:red"
    end
  end
end
