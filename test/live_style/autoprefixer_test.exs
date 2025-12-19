defmodule LiveStyle.AutoprefixerTest do
  use ExUnit.Case, async: true

  alias LiveStyle.Autoprefixer

  describe "needs_prefix?/1" do
    test "returns true for properties that need prefixes" do
      assert Autoprefixer.needs_prefix?("user-select")
      assert Autoprefixer.needs_prefix?("appearance")
      assert Autoprefixer.needs_prefix?("mask-image")
    end

    test "returns false for properties that don't need prefixes" do
      refute Autoprefixer.needs_prefix?("display")
      refute Autoprefixer.needs_prefix?("color")
      refute Autoprefixer.needs_prefix?("transform")
      refute Autoprefixer.needs_prefix?("transition")
    end
  end

  describe "prefixes_for/1" do
    test "returns correct prefixes for user-select" do
      assert Autoprefixer.prefixes_for("user-select") == ["-webkit-", "-moz-"]
    end

    test "returns correct prefixes for appearance" do
      assert Autoprefixer.prefixes_for("appearance") == ["-webkit-", "-moz-"]
    end

    test "returns correct prefixes for mask-image" do
      assert Autoprefixer.prefixes_for("mask-image") == ["-webkit-"]
    end

    test "returns empty list for properties without prefixes" do
      assert Autoprefixer.prefixes_for("display") == []
      assert Autoprefixer.prefixes_for("color") == []
    end
  end

  describe "prefix/2" do
    test "generates prefixed declarations for user-select" do
      result = Autoprefixer.prefix("user-select", "none")

      assert result == [
               {"-webkit-user-select", "none"},
               {"-moz-user-select", "none"},
               {"user-select", "none"}
             ]
    end

    test "generates prefixed declarations for appearance" do
      result = Autoprefixer.prefix("appearance", "none")

      assert result == [
               {"-webkit-appearance", "none"},
               {"-moz-appearance", "none"},
               {"appearance", "none"}
             ]
    end

    test "generates prefixed declarations for mask-image" do
      result = Autoprefixer.prefix("mask-image", "url(mask.svg)")

      assert result == [
               {"-webkit-mask-image", "url(mask.svg)"},
               {"mask-image", "url(mask.svg)"}
             ]
    end

    test "returns unprefixed only for properties without prefixes" do
      assert Autoprefixer.prefix("display", "flex") == [{"display", "flex"}]
      assert Autoprefixer.prefix("color", "red") == [{"color", "red"}]
    end
  end

  describe "prefix_css/2" do
    test "generates prefixed CSS string for user-select" do
      result = Autoprefixer.prefix_css("user-select", "none")
      assert result == "-webkit-user-select:none;-moz-user-select:none;user-select:none"
    end

    test "generates prefixed CSS string for appearance" do
      result = Autoprefixer.prefix_css("appearance", "none")
      assert result == "-webkit-appearance:none;-moz-appearance:none;appearance:none"
    end

    test "returns unprefixed CSS for properties without prefixes" do
      assert Autoprefixer.prefix_css("display", "flex") == "display:flex"
      assert Autoprefixer.prefix_css("color", "red") == "color:red"
    end
  end

  describe "config integration" do
    test "respects autoprefixer config when disabled" do
      # Disable autoprefixer
      LiveStyle.Config.put(:autoprefixer, false)

      # Should not prefix even properties that normally need it
      result = Autoprefixer.prefix("user-select", "none")
      assert result == [{"user-select", "none"}]

      # Re-enable for other tests
      LiveStyle.Config.reset(:autoprefixer)
    end
  end
end
