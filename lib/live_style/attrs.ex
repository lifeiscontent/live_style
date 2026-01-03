defmodule LiveStyle.Attrs do
  @moduledoc """
  A struct representing HTML attributes for styled elements.

  This struct implements `Phoenix.HTML.Safe` and can be spread directly
  into HEEx templates:

      ~H\"\"\"<button {css([:base, :primary])}>Click me</button>\"\"\"

  ## Fields

  - `:class` - Space-separated class names (string)
  - `:style` - Inline styles for dynamic values (string or nil)
  - `:prop_classes` - Property-to-class mappings for merging (internal use)
  """

  defstruct [:class, :style, :prop_classes]

  @type prop_classes :: [{atom() | String.t(), String.t() | :__unset__}]
  @type t :: %__MODULE__{
          class: String.t() | nil,
          style: String.t() | nil,
          prop_classes: prop_classes() | nil
        }

  @doc """
  Converts the Attrs struct to a keyword list suitable for spreading into HTML elements.

  When spreading onto a component, the full Attrs struct is passed as the class value
  so that property classes can be merged. When rendering to HTML, Phoenix.HTML.Safe
  converts the struct to just the class string.

  ## Examples

      iex> LiveStyle.Attrs.to_list(%LiveStyle.Attrs{class: "btn", style: nil})
      [class: %LiveStyle.Attrs{class: "btn", style: nil, prop_classes: nil}]

      iex> LiveStyle.Attrs.to_list(%LiveStyle.Attrs{class: "btn", style: "--x: 1"})
      [class: %LiveStyle.Attrs{class: "btn", style: "--x: 1", prop_classes: nil}, style: "--x: 1"]
  """
  @spec to_list(t()) :: keyword()
  def to_list(%__MODULE__{class: class, style: style} = attrs) do
    result = []
    result = if style && style != "", do: [{:style, style} | result], else: result
    result = if class && class != "", do: [{:class, attrs} | result], else: result
    result
  end

  @doc """
  Extracts just the class string from an Attrs struct.
  """
  @spec class_string(t()) :: String.t()
  def class_string(%__MODULE__{class: class}), do: class || ""
end

# Implement Enumerable for HEEx attribute spreading: <div {css(:class)}>
defimpl Enumerable, for: LiveStyle.Attrs do
  def count(_attrs), do: {:error, __MODULE__}

  def member?(_attrs, _element), do: {:error, __MODULE__}

  def slice(_attrs), do: {:error, __MODULE__}

  def reduce(%LiveStyle.Attrs{} = attrs, acc, fun) do
    attrs
    |> LiveStyle.Attrs.to_list()
    |> Enumerable.List.reduce(acc, fun)
  end
end

# Implement Phoenix.HTML.Safe for when Attrs struct is used as an attribute value.
# This happens when class={%Attrs{}} - we extract just the class string.
if Code.ensure_loaded?(Phoenix.HTML.Safe) do
  defimpl Phoenix.HTML.Safe, for: LiveStyle.Attrs do
    def to_iodata(%LiveStyle.Attrs{class: class}) do
      Phoenix.HTML.Safe.to_iodata(class || "")
    end
  end
end
