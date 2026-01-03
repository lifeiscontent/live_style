defmodule LiveStyle.StorageTest do
  @moduledoc """
  Tests for LiveStyle.Storage file-based manifest persistence.

  These tests verify atomic file operations and concurrent access safety.
  """
  use ExUnit.Case, async: false

  alias LiveStyle.{Manifest, Storage}

  @test_manifest_path "test/tmp/test_manifest.etf"
  @test_lock_path "test/tmp/test_manifest.etf.lock"

  setup do
    # Clean up before each test
    File.rm_rf!("test/tmp")
    File.mkdir_p!("test/tmp")

    # Set test path for this process
    Storage.set_path(@test_manifest_path)

    on_exit(fn ->
      Storage.clear_path()
      File.rm_rf!("test/tmp")
    end)

    :ok
  end

  describe "basic operations" do
    test "read returns empty manifest when file doesn't exist" do
      manifest = Storage.read()

      assert manifest.version == Manifest.current_version()
      assert manifest.vars == []
      assert manifest.classes == []
    end

    test "write and read roundtrip preserves data" do
      manifest =
        Manifest.empty()
        |> Manifest.put_var("Test.color", css_name: "--test-color", value: "red")

      Storage.write(manifest)
      read_manifest = Storage.read()

      assert Manifest.get_var(read_manifest, "Test.color") == [
               css_name: "--test-color",
               value: "red"
             ]
    end

    test "update modifies manifest atomically" do
      # Initial write
      Storage.write(Manifest.empty())

      # Update
      Storage.update(fn manifest ->
        Manifest.put_var(manifest, "Test.size", css_name: "--test-size", value: "16px")
      end)

      manifest = Storage.read()
      assert Manifest.get_var(manifest, "Test.size") == [css_name: "--test-size", value: "16px"]
    end

    test "clear removes manifest file" do
      Storage.write(Manifest.empty())
      assert File.exists?(@test_manifest_path)

      Storage.clear()
      # File is recreated with empty manifest
      manifest = Storage.read()
      assert manifest.vars == []
    end
  end

  describe "concurrent access" do
    test "multiple sequential updates accumulate correctly" do
      Storage.write(Manifest.empty())

      # Simulate multiple module compilations
      for i <- 1..10 do
        Storage.update(fn manifest ->
          Manifest.put_var(manifest, "Test.var#{i}", css_name: "--var-#{i}", value: "#{i}")
        end)
      end

      manifest = Storage.read()

      # All vars should be present
      for i <- 1..10 do
        assert Manifest.get_var(manifest, "Test.var#{i}") != nil,
               "var#{i} should exist in manifest"
      end

      assert length(manifest.vars) == 10
    end

    test "parallel updates don't lose data" do
      Storage.write(Manifest.empty())

      # Spawn multiple processes that update concurrently
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            # Each task sets its own path to avoid process dictionary conflicts
            Storage.set_path(@test_manifest_path)

            Storage.update(fn manifest ->
              Manifest.put_var(manifest, "Parallel.var#{i}",
                css_name: "--parallel-#{i}",
                value: "value#{i}"
              )
            end)
          end)
        end

      # Wait for all tasks to complete
      Task.await_many(tasks, 30_000)

      # Read final state
      manifest = Storage.read()

      # All vars should be present (no data loss from race conditions)
      present_count =
        Enum.count(1..20, fn i ->
          Manifest.get_var(manifest, "Parallel.var#{i}") != nil
        end)

      assert present_count == 20,
             "Expected all 20 vars to be present, got #{present_count}. " <>
               "This indicates a race condition in concurrent updates."
    end

    test "lock file is cleaned up after update" do
      Storage.write(Manifest.empty())

      Storage.update(fn manifest ->
        Manifest.put_var(manifest, "Test.cleanup", css_name: "--cleanup", value: "test")
      end)

      refute File.exists?(@test_lock_path), "Lock file should be removed after update"
    end
  end

  describe "process isolation (fork)" do
    test "fork creates process-local copy" do
      # Write initial state
      initial =
        Manifest.empty()
        |> Manifest.put_var("Shared.var", css_name: "--shared", value: "initial")

      Storage.write(initial)

      # Fork into this process
      Storage.fork()

      # Update process-local copy
      Storage.update(fn manifest ->
        Manifest.put_var(manifest, "Local.var", css_name: "--local", value: "local")
      end)

      # Process-local should have both
      local_manifest = Storage.read()
      assert Manifest.get_var(local_manifest, "Shared.var") != nil
      assert Manifest.get_var(local_manifest, "Local.var") != nil

      # Another process reading file should see the local update (since we write to file too)
      task =
        Task.async(fn ->
          Storage.set_path(@test_manifest_path)
          Storage.read()
        end)

      other_manifest = Task.await(task)
      assert Manifest.get_var(other_manifest, "Local.var") != nil
    end

    test "process_active? returns correct state" do
      refute Storage.process_active?()

      Storage.fork()
      assert Storage.process_active?()
    end
  end

  describe "error handling" do
    test "corrupt manifest file returns empty manifest" do
      # Write garbage to manifest file
      File.mkdir_p!(Path.dirname(@test_manifest_path))
      File.write!(@test_manifest_path, "not valid ETF data")

      manifest = Storage.read()
      assert manifest == Manifest.empty()
    end

    test "old version manifest returns empty manifest" do
      # Write manifest with old version
      old_manifest = %{
        version: 1,
        vars: [{"Old.var", [css_name: "--old", value: "old"]}],
        classes: []
      }

      File.mkdir_p!(Path.dirname(@test_manifest_path))
      File.write!(@test_manifest_path, :erlang.term_to_binary(old_manifest))

      manifest = Storage.read()

      # Should return fresh manifest, not old data
      assert manifest.version == Manifest.current_version()
      assert manifest.vars == []
    end
  end
end
