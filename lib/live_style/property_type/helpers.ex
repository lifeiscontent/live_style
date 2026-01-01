defmodule LiveStyle.PropertyType.Helpers do
  @moduledoc false

  @spec typed?(any()) :: boolean()
  def typed?(%{__type__: :typed_var}), do: true
  def typed?(_), do: false

  @spec initial_value(LiveStyle.PropertyType.typed_value()) :: String.t()
  def initial_value(%{value: value}) when is_binary(value), do: value
  def initial_value(%{value: value}) when is_integer(value), do: to_string(value)
  def initial_value(%{value: value}) when is_float(value), do: to_string(value)

  # Keyword list with :default key
  def initial_value(%{value: value}) when is_list(value) do
    case Keyword.get(value, :default) do
      nil ->
        # Fall back to first value
        case value do
          [{_key, val} | _] -> to_string(val)
          _ -> ""
        end

      val when is_binary(val) ->
        val

      val ->
        to_string(val)
    end
  end

  @spec unwrap_value(LiveStyle.PropertyType.typed_value()) :: String.t() | list()
  def unwrap_value(%{value: value}), do: value
end
