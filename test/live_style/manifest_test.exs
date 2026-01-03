defmodule LiveStyle.ManifestTest do
  @moduledoc """
  Tests for LiveStyle.Manifest structure and operations.

  These tests verify the sorted list operations that ensure deterministic
  CSS output ordering across Elixir versions.
  """
  use ExUnit.Case, async: true

  alias LiveStyle.Manifest

  describe "empty/0" do
    test "returns manifest with current version" do
      manifest = Manifest.empty()
      assert manifest.version == Manifest.current_version()
    end

    test "returns manifest with empty collections" do
      manifest = Manifest.empty()

      assert manifest.vars == []
      assert manifest.consts == []
      assert manifest.keyframes == []
      assert manifest.position_try == []
      assert manifest.view_transition_classes == []
      assert manifest.classes == []
      assert manifest.theme_classes == []
    end
  end

  describe "key/2" do
    test "creates dotted key from module and name" do
      key = Manifest.key(MyApp.Tokens, :primary)
      assert key == "MyApp.Tokens.primary"
    end

    test "handles nested modules" do
      key = Manifest.key(MyApp.Web.Components.Button, :base)
      assert key == "MyApp.Web.Components.Button.base"
    end
  end

  describe "vars operations" do
    test "put_var and get_var roundtrip" do
      manifest = Manifest.empty()
      entry = [css_name: "--color-primary", value: "blue"]

      updated = Manifest.put_var(manifest, "Test.primary", entry)
      assert Manifest.get_var(updated, "Test.primary") == entry
    end

    test "put_var maintains sorted order" do
      manifest =
        Manifest.empty()
        |> Manifest.put_var("Z.last", value: "z")
        |> Manifest.put_var("A.first", value: "a")
        |> Manifest.put_var("M.middle", value: "m")

      keys = Enum.map(manifest.vars, fn {k, _} -> k end)
      assert keys == ["A.first", "M.middle", "Z.last"]
    end

    test "put_var updates existing entry" do
      manifest =
        Manifest.empty()
        |> Manifest.put_var("Test.color", value: "red")
        |> Manifest.put_var("Test.color", value: "blue")

      assert length(manifest.vars) == 1
      assert Manifest.get_var(manifest, "Test.color") == [value: "blue"]
    end

    test "get_var returns nil for missing key" do
      manifest = Manifest.empty()
      assert Manifest.get_var(manifest, "Nonexistent.key") == nil
    end
  end

  describe "consts operations" do
    test "put_const and get_const roundtrip" do
      manifest = Manifest.empty()

      updated = Manifest.put_const(manifest, "Test.size", "16px")
      assert Manifest.get_const(updated, "Test.size") == "16px"
    end

    test "put_const maintains sorted order" do
      manifest =
        Manifest.empty()
        |> Manifest.put_const("C.third", "c")
        |> Manifest.put_const("A.first", "a")
        |> Manifest.put_const("B.second", "b")

      keys = Enum.map(manifest.consts, fn {k, _} -> k end)
      assert keys == ["A.first", "B.second", "C.third"]
    end
  end

  describe "classes operations" do
    test "put_class and get_class roundtrip" do
      manifest = Manifest.empty()
      entry = [class_string: "x123", property_classes: [{"color", "x123"}]]

      updated = Manifest.put_class(manifest, "Button.primary", entry)
      assert Manifest.get_class(updated, "Button.primary") == entry
    end

    test "put_class maintains sorted order" do
      manifest =
        Manifest.empty()
        |> Manifest.put_class("Z.last", [])
        |> Manifest.put_class("A.first", [])
        |> Manifest.put_class("M.middle", [])

      keys = Enum.map(manifest.classes, fn {k, _} -> k end)
      assert keys == ["A.first", "M.middle", "Z.last"]
    end
  end

  describe "keyframes operations" do
    test "put_keyframes and get_keyframes roundtrip" do
      manifest = Manifest.empty()
      entry = [name: "spin", css: "@keyframes spin { }"]

      updated = Manifest.put_keyframes(manifest, "Anim.spin", entry)
      assert Manifest.get_keyframes(updated, "Anim.spin") == entry
    end

    test "put_keyframes maintains sorted order" do
      manifest =
        Manifest.empty()
        |> Manifest.put_keyframes("Fade.out", [])
        |> Manifest.put_keyframes("Bounce.in", [])
        |> Manifest.put_keyframes("Spin.rotate", [])

      keys = Enum.map(manifest.keyframes, fn {k, _} -> k end)
      assert keys == ["Bounce.in", "Fade.out", "Spin.rotate"]
    end
  end

  describe "theme_classes operations" do
    test "put_theme_class and get_theme_class roundtrip" do
      manifest = Manifest.empty()
      entry = [class_name: "dark-theme", overrides: []]

      updated = Manifest.put_theme_class(manifest, "Theme.dark", entry)
      assert Manifest.get_theme_class(updated, "Theme.dark") == entry
    end
  end

  describe "ensure_keys/1" do
    test "returns fresh manifest for old version" do
      old_manifest = %{version: 1, vars: [{"old", "data"}]}

      result = Manifest.ensure_keys(old_manifest)

      assert result.version == Manifest.current_version()
      assert result.vars == []
    end

    test "preserves data for current version" do
      current =
        Manifest.empty()
        |> Manifest.put_var("Test.var", value: "test")

      result = Manifest.ensure_keys(current)

      assert Manifest.get_var(result, "Test.var") == [value: "test"]
    end

    test "returns empty for non-map input" do
      assert Manifest.ensure_keys(nil) == Manifest.empty()
      assert Manifest.ensure_keys("invalid") == Manifest.empty()
      assert Manifest.ensure_keys([]) == Manifest.empty()
    end
  end

  describe "current?/1" do
    test "returns true for current version" do
      assert Manifest.current?(Manifest.empty())
    end

    test "returns false for old version" do
      old = %{version: 1}
      refute Manifest.current?(old)
    end

    test "returns false for missing version" do
      refute Manifest.current?(%{})
      refute Manifest.current?(nil)
    end
  end

  describe "deterministic ordering" do
    test "insertion order doesn't affect final order" do
      # Insert in different orders, should get same result
      manifest1 =
        Manifest.empty()
        |> Manifest.put_var("A.a", value: "a")
        |> Manifest.put_var("B.b", value: "b")
        |> Manifest.put_var("C.c", value: "c")

      manifest2 =
        Manifest.empty()
        |> Manifest.put_var("C.c", value: "c")
        |> Manifest.put_var("A.a", value: "a")
        |> Manifest.put_var("B.b", value: "b")

      manifest3 =
        Manifest.empty()
        |> Manifest.put_var("B.b", value: "b")
        |> Manifest.put_var("C.c", value: "c")
        |> Manifest.put_var("A.a", value: "a")

      assert manifest1.vars == manifest2.vars
      assert manifest2.vars == manifest3.vars
    end

    test "multiple puts maintain consistent order" do
      manifest =
        Enum.reduce(1..100, Manifest.empty(), fn i, acc ->
          # Insert in pseudo-random order
          key = "Test.var#{rem(i * 37, 100)}"
          Manifest.put_var(acc, key, value: "#{i}")
        end)

      keys = Enum.map(manifest.vars, fn {k, _} -> k end)

      # Keys should be sorted
      assert keys == Enum.sort(keys)
    end
  end
end
