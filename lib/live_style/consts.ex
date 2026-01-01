defmodule LiveStyle.Consts do
  @moduledoc """
  Compile-time constants support for LiveStyle.

  Constants are values defined at compile time that can be referenced
  in style rules. Unlike CSS variables, constants don't generate any
  CSS output - they're purely for code organization and reuse.

  ## Examples

      defmodule MyApp.Tokens do
        use LiveStyle

        consts breakpoint_sm: "@media (max-width: 640px)",
               breakpoint_lg: "@media (min-width: 1025px)",
               z_modal: "50",
               z_tooltip: "100"
      end

      # Reference in classes
      defmodule MyApp.Components do
        use LiveStyle

        class :responsive,
          const({MyApp.Tokens, :breakpoint_sm}) => [display: "none"]
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
  """
  @spec define(module(), map() | keyword()) :: :ok
  def define(module, consts) do
    consts = Utils.normalize_to_map(consts)

    Enum.each(consts, fn {name, value} ->
      key = Manifest.simple_key(module, name)
      entry = %{value: value}
      store_entry(key, entry)
    end)

    :ok
  end
end
