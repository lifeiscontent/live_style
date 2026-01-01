defmodule LiveStyle.Property.VendorPrefixIgnoredTest do
  @moduledoc """
  Tests for vendor prefix validation with warnings disabled.

  When vendor_prefix_level is set to :ignore, no warnings should be emitted
  for vendor-prefixed properties even when prefix_css would handle them.
  """
  use LiveStyle.TestCase,
    prefix_css: &__MODULE__.mask_image_prefixer/2,
    vendor_prefix_level: :ignore

  import ExUnit.CaptureIO

  @doc false
  def mask_image_prefixer(property, value) do
    if property == "mask-image" do
      "-webkit-mask-image:#{value};mask-image:#{value}"
    else
      "#{property}:#{value}"
    end
  end

  describe "vendor prefix warnings disabled" do
    test "does not warn when vendor_prefix_level is :ignore" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              defmodule VendorPrefixIgnoredWarningTest do
                use LiveStyle, vendor_prefix_level: :ignore

                class(:with_vendor_prefix, [{:"-webkit-mask-image", "none"}])
              end
            end
          )
        end)

      refute warning =~ "Unnecessary vendor prefix"
    end
  end
end
