defmodule LiveStyle.Property.Validation.VendorPrefix do
  @moduledoc false

  @spec check(String.t(), keyword()) :: :ok
  def check(property, opts) do
    case extract_standard_property(property) do
      nil ->
        :ok

      standard_property ->
        if prefix_css_handles_property?(standard_property) do
          handle_vendor_prefix(property, standard_property, opts)
        else
          :ok
        end
    end
  end

  defp extract_standard_property(<<"-webkit-", rest::binary>>), do: rest
  defp extract_standard_property(<<"-moz-", rest::binary>>), do: rest
  defp extract_standard_property(<<"-ms-", rest::binary>>), do: rest
  defp extract_standard_property(<<"-o-", rest::binary>>), do: rest
  defp extract_standard_property(_), do: nil

  defp prefix_css_handles_property?(property) do
    case LiveStyle.Config.prefix_css() do
      nil ->
        false

      {mod, fun} ->
        result = apply(mod, fun, [property, "test"])
        result != "#{property}:test"

      fun when is_function(fun, 2) ->
        result = fun.(property, "test")
        result != "#{property}:test"
    end
  end

  defp handle_vendor_prefix(prefixed_property, standard_property, opts) do
    level = Keyword.get(opts, :vendor_prefix_level, LiveStyle.Config.vendor_prefix_level())
    file = Keyword.get(opts, :file, "unknown")
    line = Keyword.get(opts, :line, 0)

    message = build_message(prefixed_property, standard_property)
    location = if line > 0, do: "#{file}:#{line}: ", else: ""

    case level do
      :warn ->
        IO.warn("#{location}#{message}", [])
        :ok

      :ignore ->
        :ok
    end
  end

  defp build_message(prefixed_property, standard_property) do
    "Unnecessary vendor prefix '#{prefixed_property}'. " <>
      "Use '#{standard_property}' instead - prefix_css will add vendor prefixes automatically."
  end
end
