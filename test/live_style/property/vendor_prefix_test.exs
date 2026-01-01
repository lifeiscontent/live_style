defmodule LiveStyle.Property.VendorPrefixTest do
  @moduledoc """
  Tests for vendor prefix validation warnings.

  When prefix_css is configured to handle a property, using the vendor-prefixed
  version directly should warn the user to use the unprefixed version instead.
  """
  use LiveStyle.TestCase,
    prefix_css: &__MODULE__.mask_image_prefixer/2

  import ExUnit.CaptureIO

  @doc false
  def mask_image_prefixer(property, value) do
    if property == "mask-image" do
      "-webkit-mask-image:#{value};mask-image:#{value}"
    else
      "#{property}:#{value}"
    end
  end

  describe "vendor prefix warnings at compile time" do
    test "warns when defining a class with vendor-prefixed property that prefix_css handles" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              defmodule VendorPrefixWarningTest do
                use LiveStyle

                class(:with_vendor_prefix, [{:"-webkit-mask-image", "none"}])
              end
            end
          )
        end)

      assert warning =~ "Unnecessary vendor prefix '-webkit-mask-image'"
      assert warning =~ "Use 'mask-image' instead"
    end

    test "does not warn when using unprefixed property" do
      warning =
        capture_io(:stderr, fn ->
          Code.compile_quoted(
            quote do
              defmodule NoVendorPrefixWarningTest do
                use LiveStyle

                class(:without_vendor_prefix, mask_image: "none")
              end
            end
          )
        end)

      refute warning =~ "Unnecessary vendor prefix"
    end

    test "prefix_css adds vendor prefixes to generated CSS" do
      Code.compile_quoted(
        quote do
          defmodule PrefixCssOutputTest do
            use LiveStyle

            class(:mask_test, mask_image: "none")
          end
        end
      )

      css = LiveStyle.Compiler.generate_css()

      # prefix_css should add both vendor-prefixed and standard property
      assert css =~ "-webkit-mask-image:none"
      assert css =~ "mask-image:none"
    end
  end
end
