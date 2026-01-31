defmodule LiveStyle.Consts do
  @moduledoc """
  Compile-time constants support for LiveStyle.

  Constants are values defined at compile time that can be referenced
  in style rules. Unlike CSS variables, constants don't generate any
  CSS output - they're purely for code organization and reuse.

  ## Examples

      defmodule MyAppWeb.Tokens do
        use LiveStyle

        consts breakpoint_sm: "@media (max-width: 640px)",
               breakpoint_lg: "@media (min-width: 1025px)",
               z_modal: "50",
               z_tooltip: "100"
      end

      # Reference in classes
      defmodule MyAppWeb.Components do
        use LiveStyle

        class :responsive,
          const({MyAppWeb.Tokens, :breakpoint_sm}) => [display: "none"]
      end
  """

  alias LiveStyle.Manifest
  alias LiveStyle.Utils

  use LiveStyle.Registry,
    entity_name: "Constant",
    manifest_type: :const,
    ref_field: :value

  @doc """
  Defines compile-time constants.

  Called internally by the `consts` macro.
  Returns a list of `{name, value}` tuples for storage in module attributes.
  """
  @spec define(keyword()) :: [{atom(), String.t()}]
  def define(consts) do
    consts = Utils.validate_keyword_list!(consts)

    Enum.map(consts, fn {name, value} ->
      {name, value}
    end)
  end

  # Override ref/1 since const entry IS the value (not a map/keyword with :value key)
  @spec ref(atom() | {module(), atom()}) :: String.t()
  def ref(name) when is_atom(name), do: ref({__MODULE__, name})
  def ref({module, name}), do: fetch!({module, name})
end
