defmodule LiveStyle.Types.Numeric do
  @moduledoc false

  @spec integer(integer() | String.t() | map()) :: LiveStyle.Types.typed_value()
  def integer(value) when is_integer(value) do
    %{__type__: :typed_var, syntax: "<integer>", value: to_string(value)}
  end

  def integer(value) do
    %{__type__: :typed_var, syntax: "<integer>", value: value}
  end

  @spec number(number() | String.t() | map()) :: LiveStyle.Types.typed_value()
  def number(value) when is_number(value) do
    %{__type__: :typed_var, syntax: "<number>", value: to_string(value)}
  end

  def number(value) do
    %{__type__: :typed_var, syntax: "<number>", value: value}
  end
end
