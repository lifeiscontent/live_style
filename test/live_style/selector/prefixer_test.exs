defmodule LiveStyle.Selector.PrefixerTest do
  use LiveStyle.TestCase

  alias LiveStyle.Selector.Prefixer

  describe "prefix/1" do
    test "expands ::thumb to vendor-prefixed variants" do
      assert Prefixer.prefix(".x123::thumb") ==
               ".x123::-webkit-slider-thumb, .x123::-moz-range-thumb, .x123::-ms-thumb"
    end

    test "expands ::placeholder to vendor-prefixed variants" do
      assert Prefixer.prefix(".x123::placeholder") ==
               ".x123::-webkit-input-placeholder, .x123::-moz-placeholder, .x123:-ms-input-placeholder, .x123::placeholder"
    end

    test "expands ::file-selector-button to vendor-prefixed variants" do
      assert Prefixer.prefix(".x123::file-selector-button") ==
               ".x123::-webkit-file-upload-button, .x123::file-selector-button"
    end

    test "expands :fullscreen to vendor-prefixed variants" do
      assert Prefixer.prefix(".x123:fullscreen") ==
               ".x123:-webkit-full-screen, .x123:-moz-full-screen, .x123:fullscreen"
    end

    test "expands :autofill to vendor-prefixed variants" do
      assert Prefixer.prefix(".x123:autofill") ==
               ".x123:-webkit-autofill, .x123:autofill"
    end

    test "expands :placeholder-shown to vendor-prefixed variants" do
      assert Prefixer.prefix(".x123:placeholder-shown") ==
               ".x123:-moz-placeholder-shown, .x123:placeholder-shown"
    end

    test "returns selector unchanged when no prefixing needed" do
      assert Prefixer.prefix(".x123:hover") == ".x123:hover"
      assert Prefixer.prefix(".x123:focus") == ".x123:focus"
      assert Prefixer.prefix(".x123::before") == ".x123::before"
      assert Prefixer.prefix(".x123::after") == ".x123::after"
    end

    test "handles complex selectors with ::thumb" do
      assert Prefixer.prefix(".x123:hover::thumb") ==
               ".x123:hover::-webkit-slider-thumb, .x123:hover::-moz-range-thumb, .x123:hover::-ms-thumb"
    end

    test "handles complex selectors with ::placeholder" do
      assert Prefixer.prefix(".x123:focus::placeholder") ==
               ".x123:focus::-webkit-input-placeholder, .x123:focus::-moz-placeholder, .x123:focus:-ms-input-placeholder, .x123:focus::placeholder"
    end

    test "handles selector with specificity bump" do
      assert Prefixer.prefix(".x123.x123::thumb") ==
               ".x123.x123::-webkit-slider-thumb, .x123.x123::-moz-range-thumb, .x123.x123::-ms-thumb"
    end
  end

  describe "needs_prefix?/1" do
    test "returns true for selectors that need prefixing" do
      assert Prefixer.needs_prefix?(".x123::thumb") == true
      assert Prefixer.needs_prefix?(".x123::placeholder") == true
      assert Prefixer.needs_prefix?(".x123:fullscreen") == true
      assert Prefixer.needs_prefix?(".x123:autofill") == true
      assert Prefixer.needs_prefix?(".x123:placeholder-shown") == true
      assert Prefixer.needs_prefix?(".x123::file-selector-button") == true
    end

    test "returns false for selectors that don't need prefixing" do
      assert Prefixer.needs_prefix?(".x123:hover") == false
      assert Prefixer.needs_prefix?(".x123:focus") == false
      assert Prefixer.needs_prefix?(".x123::before") == false
      assert Prefixer.needs_prefix?(".x123::after") == false
    end
  end

  describe "variants_for/1" do
    test "returns variants for ::thumb" do
      assert Prefixer.variants_for("::thumb") == [
               "::-webkit-slider-thumb",
               "::-moz-range-thumb",
               "::-ms-thumb"
             ]
    end

    test "returns variants for ::placeholder" do
      assert Prefixer.variants_for("::placeholder") == [
               "::-webkit-input-placeholder",
               "::-moz-placeholder",
               ":-ms-input-placeholder",
               "::placeholder"
             ]
    end

    test "returns variants for :fullscreen" do
      assert Prefixer.variants_for(":fullscreen") == [
               ":-webkit-full-screen",
               ":-moz-full-screen",
               ":fullscreen"
             ]
    end

    test "returns nil for unhandled selectors" do
      assert Prefixer.variants_for(":hover") == nil
      assert Prefixer.variants_for("::before") == nil
    end
  end

  describe "handled_selectors/0" do
    test "returns list of all handled selectors" do
      selectors = Prefixer.handled_selectors()

      assert "::thumb" in selectors
      assert "::placeholder" in selectors
      assert "::file-selector-button" in selectors
      assert ":fullscreen" in selectors
      assert ":autofill" in selectors
      assert ":placeholder-shown" in selectors
    end
  end
end
