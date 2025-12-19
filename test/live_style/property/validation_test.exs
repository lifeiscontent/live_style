defmodule LiveStyle.Property.ValidationTest do
  use ExUnit.Case, async: false

  alias LiveStyle.Property.Validation

  import ExUnit.CaptureIO

  setup do
    # Reset config after each test
    on_exit(fn ->
      LiveStyle.Config.reset_all()
      Application.delete_env(:live_style, :prefixer)
      Application.delete_env(:live_style, :vendor_prefix_level)
    end)

    :ok
  end

  describe "validate/1" do
    test "returns :ok for known properties" do
      assert Validation.validate("color") == :ok
      assert Validation.validate("background-color") == :ok
      assert Validation.validate("margin") == :ok
    end

    test "returns :ok for custom properties" do
      assert Validation.validate("--my-custom-prop") == :ok
      assert Validation.validate("--theme-color") == :ok
    end

    test "returns {:unknown, suggestions} for unknown properties" do
      assert {:unknown, suggestions} = Validation.validate("colr")
      assert "color" in suggestions
    end

    test "returns {:unknown, []} when no similar properties found" do
      assert {:unknown, []} = Validation.validate("zzzznotaproperty")
    end
  end

  describe "known?/1" do
    test "returns true for known properties" do
      assert Validation.known?("color") == true
      assert Validation.known?("display") == true
    end

    test "returns true for custom properties" do
      assert Validation.known?("--custom") == true
    end

    test "returns false for unknown properties" do
      assert Validation.known?("not-a-property") == false
    end

    test "returns true for vendor-prefixed properties" do
      assert Validation.known?("-webkit-transform") == true
      assert Validation.known?("-moz-appearance") == true
    end
  end

  describe "validate!/2 with vendor prefix checking" do
    test "warns when using vendor-prefixed property that prefixer handles" do
      # Configure a prefixer that handles mask-image
      Application.put_env(:live_style, :prefixer, fn property, value ->
        if property == "mask-image" do
          "-webkit-mask-image:#{value};mask-image:#{value}"
        else
          "#{property}:#{value}"
        end
      end)

      warning =
        capture_io(:stderr, fn ->
          Validation.validate!("-webkit-mask-image")
        end)

      assert warning =~ "Unnecessary vendor prefix '-webkit-mask-image'"
      assert warning =~ "Use 'mask-image' instead"
    end

    test "does not warn for vendor-prefixed property when prefixer doesn't handle it" do
      # Configure a prefixer that doesn't handle font-smoothing
      Application.put_env(:live_style, :prefixer, fn property, value ->
        "#{property}:#{value}"
      end)

      warning =
        capture_io(:stderr, fn ->
          Validation.validate!("-webkit-font-smoothing")
        end)

      # Should not warn about vendor prefix since prefixer doesn't handle it
      refute warning =~ "Unnecessary vendor prefix"
    end

    test "does not warn when no prefixer is configured" do
      Application.delete_env(:live_style, :prefixer)

      warning =
        capture_io(:stderr, fn ->
          Validation.validate!("-webkit-mask-image")
        end)

      refute warning =~ "Unnecessary vendor prefix"
    end

    test "does not warn when vendor_prefix_level is :ignore" do
      Application.put_env(:live_style, :prefixer, fn property, value ->
        if property == "mask-image" do
          "-webkit-mask-image:#{value};mask-image:#{value}"
        else
          "#{property}:#{value}"
        end
      end)

      Application.put_env(:live_style, :vendor_prefix_level, :ignore)

      warning =
        capture_io(:stderr, fn ->
          Validation.validate!("-webkit-mask-image")
        end)

      refute warning =~ "Unnecessary vendor prefix"
    end

    test "does not warn for standard properties" do
      Application.put_env(:live_style, :prefixer, fn property, value ->
        "#{property}:#{value}"
      end)

      warning =
        capture_io(:stderr, fn ->
          Validation.validate!("mask-image")
        end)

      refute warning =~ "Unnecessary vendor prefix"
    end
  end

  describe "find_suggestions/1" do
    test "returns similar property names" do
      suggestions = Validation.find_suggestions("colr")
      assert "color" in suggestions
    end

    test "returns multiple suggestions sorted by similarity" do
      suggestions = Validation.find_suggestions("backgrund")
      assert length(suggestions) > 0
      assert Enum.any?(suggestions, &String.contains?(&1, "background"))
    end

    test "returns at most 3 suggestions" do
      suggestions = Validation.find_suggestions("margin")
      assert length(suggestions) <= 3
    end

    test "returns empty list for completely dissimilar input" do
      suggestions = Validation.find_suggestions("xyznothing")
      assert suggestions == []
    end
  end
end
