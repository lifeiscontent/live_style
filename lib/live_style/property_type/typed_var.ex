defmodule LiveStyle.PropertyType.TypedVar do
  @moduledoc false

  alias LiveStyle.PropertyType.Simple

  @spec typed_var(atom() | String.t(), String.t() | map(), keyword()) ::
          LiveStyle.PropertyType.typed_value()
  def typed_var(syntax, value, opts \\ [])

  def typed_var(syntax, value, opts) when is_atom(syntax) do
    inherits = Keyword.get(opts, :inherits, false)
    css_syntax = Simple.atom_to_syntax(syntax)
    %{__type__: :typed_var, syntax: css_syntax, value: value, inherits: inherits}
  end

  def typed_var(syntax, value, opts) when is_binary(syntax) do
    inherits = Keyword.get(opts, :inherits, false)
    %{__type__: :typed_var, syntax: syntax, value: value, inherits: inherits}
  end
end
