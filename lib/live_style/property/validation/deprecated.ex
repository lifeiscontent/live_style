defmodule LiveStyle.Property.Validation.Deprecated do
  @moduledoc false

  @spec check(String.t(), keyword()) :: :ok
  def check(<<"--", _::binary>>, _opts), do: :ok

  def check(property, opts) do
    if deprecated?(property) do
      handle(property, opts)
    else
      :ok
    end
  end

  defp deprecated?(property) do
    case LiveStyle.Config.deprecated?() do
      nil -> false
      {mod, fun} -> apply(mod, fun, [property])
      fun when is_function(fun, 1) -> fun.(property)
    end
  end

  defp handle(property, opts) do
    level =
      Keyword.get(opts, :deprecated_property_level, LiveStyle.Config.deprecated_property_level())

    file = Keyword.get(opts, :file, "unknown")
    line = Keyword.get(opts, :line, 0)

    message = "CSS property '#{property}' is deprecated. Consider using a modern alternative."
    location = if line > 0, do: "#{file}:#{line}: ", else: ""

    case level do
      :warn ->
        IO.warn("#{location}#{message}", [])
        :ok

      :ignore ->
        :ok
    end
  end
end
