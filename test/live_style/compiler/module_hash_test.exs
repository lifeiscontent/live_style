defmodule LiveStyle.Compiler.ModuleHashTest do
  @moduledoc """
  Tests for LiveStyle.Compiler.ModuleHash content hashing.

  These tests verify that the hash computation is:
  - Deterministic (same input → same hash)
  - Change-sensitive (different input → different hash)
  - Order-independent (insertion order doesn't affect hash)
  """
  use ExUnit.Case, async: false

  alias LiveStyle.Compiler.{ModuleData, ModuleHash}
  alias LiveStyle.{Manifest, Storage}

  @test_manifest_path "test/tmp/module_hash_manifest.etf"

  setup do
    File.rm_rf!("test/tmp")
    File.mkdir_p!("test/tmp")
    Storage.set_path(@test_manifest_path)

    # Clean up any cached module data for test modules
    modules_dir = ModuleData.modules_dir()

    for module <- [TestModule, OtherModule, AModule, MModule, ZModule] do
      hash = :crypto.hash(:md5, inspect(module)) |> Base.encode16(case: :lower)
      path = Path.join(modules_dir, "#{hash}.etf")
      File.rm(path)
    end

    on_exit(fn ->
      Storage.clear_path()
      File.rm_rf!("test/tmp")
    end)

    :ok
  end

  describe "compute/8" do
    test "returns consistent hash for same inputs" do
      classes = [{:button, [display: "flex"], []}]
      vars = [{:primary, [ident: "--v123", value: "#3b82f6"]}]
      consts = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      assert hash1 == hash2
      assert is_binary(hash1)
      assert byte_size(hash1) == 16
    end

    test "returns different hash when classes change" do
      vars = [{:primary, [ident: "--v123", value: "#3b82f6"]}]
      consts = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          [{:button, [display: "flex"], []}],
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          [{:button, [display: "block"], []}],
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      refute hash1 == hash2
    end

    test "returns different hash when vars change" do
      classes = [{:button, [display: "flex"], []}]
      consts = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes,
          [{:primary, [ident: "--v123", value: "#3b82f6"]}],
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes,
          [{:primary, [ident: "--v123", value: "#ff0000"]}],
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      refute hash1 == hash2
    end

    test "returns different hash when module changes" do
      classes = [{:button, [display: "flex"], []}]
      vars = []
      consts = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          ModuleA,
          classes,
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          ModuleB,
          classes,
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      refute hash1 == hash2
    end

    test "hash is order-independent for classes" do
      vars = []
      consts = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      classes1 = [
        {:alpha, [display: "flex"], []},
        {:beta, [color: "red"], []},
        {:gamma, [padding: "8px"], []}
      ]

      classes2 = [
        {:gamma, [padding: "8px"], []},
        {:alpha, [display: "flex"], []},
        {:beta, [color: "red"], []}
      ]

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes1,
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes2,
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      assert hash1 == hash2
    end

    test "hash is order-independent for vars" do
      classes = []
      consts = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      vars1 = [
        {:alpha, [value: "a"]},
        {:beta, [value: "b"]},
        {:gamma, [value: "c"]}
      ]

      vars2 = [
        {:gamma, [value: "c"]},
        {:alpha, [value: "a"]},
        {:beta, [value: "b"]}
      ]

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars1,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars2,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      assert hash1 == hash2
    end

    test "returns different hash when adding a new class" do
      vars = []
      consts = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          [{:button, [display: "flex"], []}],
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          [{:button, [display: "flex"], []}, {:card, [padding: "16px"], []}],
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      refute hash1 == hash2
    end

    test "returns different hash when keyframes change" do
      classes = []
      vars = []
      consts = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          [{:spin, [ident: "k123", frames: []]}],
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          [{:fade, [ident: "k456", frames: []]}],
          theme_classes,
          view_transition_classes,
          position_try
        )

      refute hash1 == hash2
    end

    test "returns different hash when consts change" do
      classes = []
      vars = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          [{:spacing_sm, "4px"}],
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          [{:spacing_sm, "8px"}],
          keyframes,
          theme_classes,
          view_transition_classes,
          position_try
        )

      refute hash1 == hash2
    end

    test "returns different hash when theme_classes change" do
      classes = []
      vars = []
      consts = []
      keyframes = []
      view_transition_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          keyframes,
          [{:dark, [selector: ".dark", vars: [primary: "#fff"]]}],
          view_transition_classes,
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          keyframes,
          [{:dark, [selector: ".dark", vars: [primary: "#000"]]}],
          view_transition_classes,
          position_try
        )

      refute hash1 == hash2
    end

    test "returns different hash when view_transition_classes change" do
      classes = []
      vars = []
      consts = []
      keyframes = []
      theme_classes = []
      position_try = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          keyframes,
          theme_classes,
          [{:slide, [ident: "vt-slide", old: [], new: []]}],
          position_try
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          keyframes,
          theme_classes,
          [{:fade, [ident: "vt-fade", old: [], new: []]}],
          position_try
        )

      refute hash1 == hash2
    end

    test "returns different hash when position_try change" do
      classes = []
      vars = []
      consts = []
      keyframes = []
      theme_classes = []
      view_transition_classes = []

      hash1 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          [{:top, [ident: "pt-top", props: [top: "0"]]}]
        )

      hash2 =
        ModuleHash.compute(
          TestModule,
          classes,
          vars,
          consts,
          keyframes,
          theme_classes,
          view_transition_classes,
          [{:bottom, [ident: "pt-bottom", props: [bottom: "0"]]}]
        )

      refute hash1 == hash2
    end
  end

  describe "get_stored_hash/1" do
    test "returns nil when no module data exists" do
      assert ModuleHash.get_stored_hash(TestModule) == nil
    end

    test "returns nil when module data has no hash" do
      # Write module data without a hash
      ModuleData.write(OtherModule, %{module: OtherModule, classes: %{}})

      assert ModuleHash.get_stored_hash(TestModule) == nil
    end

    test "returns stored hash when module data exists" do
      expected_hash = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>

      # Write module data with a hash
      ModuleData.write(TestModule, %{module: TestModule, module_hash: expected_hash})

      assert ModuleHash.get_stored_hash(TestModule) == expected_hash
    end
  end

  describe "Manifest.module_hashes operations" do
    test "put_module_hash and get_module_hash roundtrip" do
      hash = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>

      manifest =
        Manifest.empty()
        |> Manifest.put_module_hash(TestModule, hash)

      assert Manifest.get_module_hash(manifest, TestModule) == hash
    end

    test "put_module_hash maintains sorted order" do
      manifest =
        Manifest.empty()
        |> Manifest.put_module_hash(ZModule, <<0::128>>)
        |> Manifest.put_module_hash(AModule, <<1::128>>)
        |> Manifest.put_module_hash(MModule, <<2::128>>)

      modules = Enum.map(manifest.module_hashes, fn {mod, _} -> mod end)
      assert modules == Enum.sort(modules)
    end

    test "put_module_hash updates existing entry" do
      old_hash = <<0::128>>
      new_hash = <<1::128>>

      manifest =
        Manifest.empty()
        |> Manifest.put_module_hash(TestModule, old_hash)
        |> Manifest.put_module_hash(TestModule, new_hash)

      assert length(manifest.module_hashes) == 1
      assert Manifest.get_module_hash(manifest, TestModule) == new_hash
    end

    test "get_module_hash returns nil for missing module" do
      manifest = Manifest.empty()
      assert Manifest.get_module_hash(manifest, NonexistentModule) == nil
    end

    test "module_hashes included in empty manifest" do
      manifest = Manifest.empty()
      assert manifest.module_hashes == []
    end
  end
end
