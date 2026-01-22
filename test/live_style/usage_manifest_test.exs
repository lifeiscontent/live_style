defmodule LiveStyle.UsageManifestTest do
  @moduledoc """
  Tests for LiveStyle.UsageManifest usage tracking data structure.
  """
  use ExUnit.Case, async: true

  alias LiveStyle.UsageManifest

  describe "empty/0" do
    test "returns an empty MapSet" do
      usage = UsageManifest.empty()
      assert usage == MapSet.new()
      assert UsageManifest.size(usage) == 0
    end
  end

  describe "record_usage/3" do
    test "records a single class usage" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)

      assert UsageManifest.size(usage) == 1
      assert UsageManifest.used?(usage, MyApp.Button, :primary)
    end

    test "records multiple usages" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)
        |> UsageManifest.record_usage(MyApp.Button, :secondary)
        |> UsageManifest.record_usage(MyApp.Card, :base)

      assert UsageManifest.size(usage) == 3
      assert UsageManifest.used?(usage, MyApp.Button, :primary)
      assert UsageManifest.used?(usage, MyApp.Button, :secondary)
      assert UsageManifest.used?(usage, MyApp.Card, :base)
    end

    test "duplicate usages are idempotent" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)
        |> UsageManifest.record_usage(MyApp.Button, :primary)
        |> UsageManifest.record_usage(MyApp.Button, :primary)

      assert UsageManifest.size(usage) == 1
    end
  end

  describe "used?/3" do
    test "returns true for recorded usage" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)

      assert UsageManifest.used?(usage, MyApp.Button, :primary)
    end

    test "returns false for unrecorded usage" do
      usage = UsageManifest.empty()

      refute UsageManifest.used?(usage, MyApp.Button, :primary)
    end

    test "distinguishes between different classes in same module" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)

      assert UsageManifest.used?(usage, MyApp.Button, :primary)
      refute UsageManifest.used?(usage, MyApp.Button, :secondary)
    end

    test "distinguishes between same class in different modules" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :base)

      assert UsageManifest.used?(usage, MyApp.Button, :base)
      refute UsageManifest.used?(usage, MyApp.Card, :base)
    end
  end

  describe "key_used?/2" do
    test "returns true for recorded usage with valid key" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)

      assert UsageManifest.key_used?(usage, "Elixir.MyApp.Button.primary")
    end

    test "returns false for unrecorded usage" do
      usage = UsageManifest.empty()

      refute UsageManifest.key_used?(usage, "Elixir.MyApp.Button.primary")
    end

    test "returns false for malformed key" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)

      refute UsageManifest.key_used?(usage, "invalid")
      refute UsageManifest.key_used?(usage, "")
    end

    test "handles deeply nested module names" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Web.Components.UI.Button, :primary)

      assert UsageManifest.key_used?(usage, "Elixir.MyApp.Web.Components.UI.Button.primary")
    end
  end

  describe "merge/2" do
    test "merges two empty manifests" do
      merged = UsageManifest.merge(UsageManifest.empty(), UsageManifest.empty())
      assert UsageManifest.size(merged) == 0
    end

    test "merges non-overlapping manifests" do
      usage1 =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)

      usage2 =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Card, :base)

      merged = UsageManifest.merge(usage1, usage2)

      assert UsageManifest.size(merged) == 2
      assert UsageManifest.used?(merged, MyApp.Button, :primary)
      assert UsageManifest.used?(merged, MyApp.Card, :base)
    end

    test "merges overlapping manifests without duplicates" do
      usage1 =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)
        |> UsageManifest.record_usage(MyApp.Button, :secondary)

      usage2 =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)
        |> UsageManifest.record_usage(MyApp.Card, :base)

      merged = UsageManifest.merge(usage1, usage2)

      assert UsageManifest.size(merged) == 3
    end
  end

  describe "to_list/1" do
    test "returns empty list for empty manifest" do
      assert UsageManifest.to_list(UsageManifest.empty()) == []
    end

    test "returns list of tuples" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)
        |> UsageManifest.record_usage(MyApp.Card, :base)

      list = UsageManifest.to_list(usage)

      assert length(list) == 2
      assert {MyApp.Button, :primary} in list
      assert {MyApp.Card, :base} in list
    end
  end

  describe "size/1" do
    test "returns 0 for empty manifest" do
      assert UsageManifest.size(UsageManifest.empty()) == 0
    end

    test "returns correct count" do
      usage =
        UsageManifest.empty()
        |> UsageManifest.record_usage(MyApp.Button, :primary)
        |> UsageManifest.record_usage(MyApp.Button, :secondary)
        |> UsageManifest.record_usage(MyApp.Card, :base)

      assert UsageManifest.size(usage) == 3
    end
  end
end
