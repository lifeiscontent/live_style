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
  Creates a new Attrs struct.

  ## Examples

      iex> LiveStyle.Attrs.new("btn primary", nil)
      %LiveStyle.Attrs{class: "btn primary", style: nil}

      iex> LiveStyle.Attrs.new("btn", "--opacity: 0.5")
      %LiveStyle.Attrs{class: "btn", style: "--opacity: 0.5"}
  """
  @spec new(String.t() | nil, String.t() | nil) :: t()
  def new(class, style) do
    %__MODULE__{class: class, style: style}
  end

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

# Implement Access behaviour for pattern matching and direct spreading
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
