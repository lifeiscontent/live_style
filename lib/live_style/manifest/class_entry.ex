defmodule LiveStyle.Manifest.ClassEntry do
  @moduledoc """
  Entry structure for style classes.

  There are two variants:
  - Static classes: have declarations
  - Dynamic classes: have all_props
  """

  @type static_entry :: [
          class_string: String.t(),
          atomic_classes: list(),
          declarations: keyword()
        ]

  @type dynamic_entry :: [
          class_string: String.t(),
          atomic_classes: list(),
          all_props: [atom()]
        ]

  @type t :: static_entry() | dynamic_entry()

  @doc """
  Creates a new static class entry.

  ## Parameters

    * `class_string` - The space-separated class names
    * `atomic_classes` - List of atomic class definitions
    * `declarations` - The original style declarations

  ## Examples

      ClassEntry.new_static("x1abc x2def", [...], [display: "flex"])
  """
  @spec new_static(String.t(), list(), keyword()) :: static_entry()
  def new_static(class_string, atomic_classes, declarations) do
    [
      class_string: class_string,
      atomic_classes: atomic_classes,
      declarations: declarations
    ]
  end

  @doc """
  Creates a new dynamic class entry.

  ## Parameters

    * `class_string` - The space-separated class names
    * `atomic_classes` - List of atomic class definitions
    * `all_props` - All properties this dynamic class can set

  ## Examples

      ClassEntry.new_dynamic("x1abc", [...], [:opacity])
  """
  @spec new_dynamic(String.t(), list(), [atom()]) :: dynamic_entry()
  def new_dynamic(class_string, atomic_classes, all_props) do
    [
      class_string: class_string,
      atomic_classes: atomic_classes,
      all_props: all_props
    ]
  end

  @doc """
  Gets the class string from an entry.
  """
  @spec class_string(t()) :: String.t()
  def class_string(entry), do: Keyword.fetch!(entry, :class_string)

  @doc """
  Gets the atomic classes from an entry.
  """
  @spec atomic_classes(t()) :: list()
  def atomic_classes(entry), do: Keyword.fetch!(entry, :atomic_classes)

  @doc """
  Returns true if this is a dynamic class entry.
  """
  @spec dynamic?(t()) :: boolean()
  def dynamic?(entry), do: Keyword.has_key?(entry, :all_props)

  @doc """
  Gets the declarations from a static class entry.
  Raises if called on a dynamic entry.
  """
  @spec declarations(static_entry()) :: keyword()
  def declarations(entry), do: Keyword.fetch!(entry, :declarations)

  @doc """
  Gets all_props from a dynamic class entry.
  Raises if called on a static entry.
  """
  @spec all_props(dynamic_entry()) :: [atom()]
  def all_props(entry), do: Keyword.fetch!(entry, :all_props)
end
