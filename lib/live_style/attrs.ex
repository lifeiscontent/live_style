defmodule LiveStyle.Attrs do
  @moduledoc """
  A struct representing HTML attributes for styled elements.

  This struct implements `Phoenix.HTML.Safe` and can be spread directly
  into HEEx templates:

      ~H\"\"\"<button {css([:base, :primary])}>Click me</button>\"\"\"

  ## Fields

  - `:class` - Space-separated class names (string)
  - `:style` - Inline styles for dynamic values (string or nil)
  """

  defstruct [:class, :style]

  @type t :: %__MODULE__{
          class: String.t() | nil,
          style: String.t() | nil
        }

  @doc """
  Converts the Attrs struct to a keyword list suitable for spreading into HTML elements.

  ## Examples

      iex> LiveStyle.Attrs.to_list(%LiveStyle.Attrs{class: "btn", style: nil})
      [class: "btn"]

      iex> LiveStyle.Attrs.to_list(%LiveStyle.Attrs{class: "btn", style: "--x: 1"})
      [class: "btn", style: "--x: 1"]
  """
  @spec to_list(t()) :: keyword()
  def to_list(%__MODULE__{class: class, style: style}) do
    attrs = []
    attrs = if style && style != "", do: [{:style, style} | attrs], else: attrs
    attrs = if class && class != "", do: [{:class, class} | attrs], else: attrs
    attrs
  end
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

# Implement Phoenix.HTML.Safe for spreading into templates
if Code.ensure_loaded?(Phoenix.HTML.Safe) do
  defimpl Phoenix.HTML.Safe, for: LiveStyle.Attrs do
    def to_iodata(%LiveStyle.Attrs{} = attrs) do
      attrs
      |> LiveStyle.Attrs.to_list()
      |> Phoenix.HTML.attributes_escape()
    end
  end
end
