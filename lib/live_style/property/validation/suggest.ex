defmodule LiveStyle.Property.Validation.Suggest do
  @moduledoc false

  alias LiveStyle.Property.Validation.Known

  @spec validate(String.t()) :: :ok | {:unknown, [String.t()]}
  def validate(property) do
    if Known.known?(property) do
      :ok
    else
      {:unknown, find_suggestions(property)}
    end
  end

  @spec find_suggestions(String.t()) :: [String.t()]
  def find_suggestions(property) do
    property_downcase = String.downcase(property)

    Known.known_properties()
    |> Enum.map(fn known ->
      {known, String.jaro_distance(property_downcase, String.downcase(known))}
    end)
    |> Enum.filter(fn {_prop, score} -> score > 0.8 end)
    |> Enum.sort_by(fn {_prop, score} -> -score end)
    |> Enum.take(3)
    |> Enum.map(fn {prop, _score} -> prop end)
  end

  @spec build_unknown_message(String.t(), [String.t()]) :: String.t()
  def build_unknown_message(property, []), do: "Unknown CSS property '#{property}'"

  def build_unknown_message(property, suggestions) do
    suggestion_text = Enum.join(suggestions, ", ")
    "Unknown CSS property '#{property}'. Did you mean: #{suggestion_text}?"
  end
end
