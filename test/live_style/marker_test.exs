defmodule LiveStyle.MarkerTest do
  @moduledoc """
  Tests for markers (contextual selectors).
  """
  use LiveStyle.TestCase
  import LiveStyle, only: [marker: 1]

  describe "default_marker" do
    test "returns a marker struct" do
      marker = LiveStyle.default_marker()
      assert %LiveStyle.Marker{} = marker
    end

    test "class contains the configured prefix" do
      marker = LiveStyle.default_marker()
      assert marker.class =~ "x-default-marker"
    end
  end

  describe "marker/1 local reference" do
    test "returns a marker struct" do
      result = marker(:row)
      assert %LiveStyle.Marker{} = result
    end

    test "marker class is consistent for same name" do
      marker1 = marker(:card)
      marker2 = marker(:card)
      assert marker1.class == marker2.class
    end

    test "different names produce different markers" do
      marker1 = marker(:card)
      marker2 = marker(:row)
      refute marker1.class == marker2.class
    end
  end

  describe "marker/1 cross-module reference" do
    test "different modules produce different markers" do
      marker1 = marker({ModuleA, :item})
      marker2 = marker({ModuleB, :item})
      refute marker1.class == marker2.class
    end

    test "same name in different modules are independent" do
      marker1 = marker({MyApp.ComponentA, :row})
      marker2 = marker({MyApp.ComponentB, :row})
      refute marker1.class == marker2.class
    end

    test "cross-module reference matches local in that module" do
      # marker(:row) in this module should equal marker({__MODULE__, :row})
      local = marker(:row)
      cross = marker({__MODULE__, :row})
      assert local.class == cross.class
    end
  end
end
