defmodule LiveStyle.TreeShakingTest do
  @moduledoc """
  Integration tests for StyleX-style tree shaking (emit only used styles).
  """
  use ExUnit.Case, async: false

  alias LiveStyle.Compiler.CSS.Classes.Collector
  alias LiveStyle.{Manifest, Storage, UsageManifest}

  @test_manifest_path "test/tmp/tree_shaking_manifest.etf"
  @test_usage_path "test/tmp/tree_shaking_usage.etf"

  setup do
    # Clean up before each test
    File.rm_rf!("test/tmp")
    File.mkdir_p!("test/tmp")

    # Set test paths for this process
    Storage.set_path(@test_manifest_path)
    Storage.set_usage_path(@test_usage_path)

    # Start with fresh manifests
    Storage.write(Manifest.empty())
    Storage.clear_usage()

    on_exit(fn ->
      Storage.clear_path()
      Storage.clear_usage_path()
      File.rm_rf!("test/tmp")
    end)

    :ok
  end

  describe "Collector tree shaking" do
    test "only used classes are emitted" do
      # Create a manifest with two classes
      manifest = create_test_manifest()

      # Record usage for only one class
      Storage.update_usage(fn usage ->
        UsageManifest.record_usage(usage, TreeShakingTest.TestModule, :used_class)
      end)

      collected = Collector.collect(manifest)

      # Only the used class should be present
      class_names = Enum.map(collected, fn {class_name, _, _, _, _} -> class_name end)
      assert "x-used" in class_names
      refute "x-unused" in class_names
    end

    test "emits nothing when no classes are used" do
      manifest = create_test_manifest()

      # No usage recorded
      collected = Collector.collect(manifest)

      assert collected == []
    end

    test "handles multiple used classes" do
      manifest = create_test_manifest_with_three_classes()

      # Record usage for two classes
      Storage.update_usage(fn usage ->
        usage
        |> UsageManifest.record_usage(TreeShakingTest.TestModule, :class_a)
        |> UsageManifest.record_usage(TreeShakingTest.TestModule, :class_c)
      end)

      collected = Collector.collect(manifest)

      class_names = Enum.map(collected, fn {class_name, _, _, _, _} -> class_name end)
      assert "x-a" in class_names
      assert "x-c" in class_names
      refute "x-b" in class_names
    end

    test "emits all classes when all are used" do
      manifest = create_test_manifest()

      # Record usage for both classes
      Storage.update_usage(fn usage ->
        usage
        |> UsageManifest.record_usage(TreeShakingTest.TestModule, :used_class)
        |> UsageManifest.record_usage(TreeShakingTest.TestModule, :unused_class)
      end)

      collected = Collector.collect(manifest)

      class_names = Enum.map(collected, fn {class_name, _, _, _, _} -> class_name end)
      assert "x-used" in class_names
      assert "x-unused" in class_names
    end
  end

  describe "cross-module usage" do
    test "tracks usage from different modules" do
      manifest = create_cross_module_manifest()

      # Record usage from Module A using a class from Module B
      Storage.update_usage(fn usage ->
        UsageManifest.record_usage(usage, TreeShakingTest.ModuleB, :shared_style)
      end)

      collected = Collector.collect(manifest)

      class_names = Enum.map(collected, fn {class_name, _, _, _, _} -> class_name end)
      assert "x-shared" in class_names
      refute "x-local" in class_names
    end
  end

  describe "Storage usage operations" do
    test "read_usage returns empty manifest initially" do
      usage = Storage.read_usage()
      assert UsageManifest.size(usage) == 0
    end

    test "update_usage persists changes" do
      Storage.update_usage(fn usage ->
        UsageManifest.record_usage(usage, MyModule, :my_class)
      end)

      usage = Storage.read_usage()
      assert UsageManifest.used?(usage, MyModule, :my_class)
    end

    test "clear_usage removes all usage data" do
      Storage.update_usage(fn usage ->
        UsageManifest.record_usage(usage, MyModule, :my_class)
      end)

      Storage.clear_usage()

      usage = Storage.read_usage()
      refute UsageManifest.used?(usage, MyModule, :my_class)
    end

    test "concurrent updates accumulate correctly" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            Storage.set_usage_path(@test_usage_path)

            Storage.update_usage(fn usage ->
              UsageManifest.record_usage(usage, MyModule, :"class_#{i}")
            end)
          end)
        end

      Task.await_many(tasks, 30_000)

      usage = Storage.read_usage()

      # All usages should be present
      for i <- 1..10 do
        assert UsageManifest.used?(usage, MyModule, :"class_#{i}"),
               "class_#{i} should be recorded"
      end
    end
  end

  # Helper functions to create test manifests

  defp create_test_manifest do
    key_used = "Elixir.TreeShakingTest.TestModule.used_class"
    key_unused = "Elixir.TreeShakingTest.TestModule.unused_class"

    Manifest.empty()
    |> Manifest.put_class(key_used, create_class_entry("x-used", "color", "red"))
    |> Manifest.put_class(key_unused, create_class_entry("x-unused", "color", "blue"))
  end

  defp create_test_manifest_with_three_classes do
    key_a = "Elixir.TreeShakingTest.TestModule.class_a"
    key_b = "Elixir.TreeShakingTest.TestModule.class_b"
    key_c = "Elixir.TreeShakingTest.TestModule.class_c"

    Manifest.empty()
    |> Manifest.put_class(key_a, create_class_entry("x-a", "color", "red"))
    |> Manifest.put_class(key_b, create_class_entry("x-b", "color", "green"))
    |> Manifest.put_class(key_c, create_class_entry("x-c", "color", "blue"))
  end

  defp create_cross_module_manifest do
    key_shared = "Elixir.TreeShakingTest.ModuleB.shared_style"
    key_local = "Elixir.TreeShakingTest.ModuleA.local_style"

    Manifest.empty()
    |> Manifest.put_class(key_shared, create_class_entry("x-shared", "display", "flex"))
    |> Manifest.put_class(key_local, create_class_entry("x-local", "display", "block"))
  end

  defp create_class_entry(class_name, property, value) do
    [
      declarations: [{String.to_atom(property), value}],
      atomic_classes: [
        {property,
         [
           class: class_name,
           ltr: ".#{class_name}{#{property}:#{value}}",
           rtl: nil,
           priority: 3000
         ]}
      ]
    ]
  end
end
