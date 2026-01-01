defmodule LiveStyle.Property.Validation.Known do
  @moduledoc false

  alias LiveStyle.PropertyMetadata.Parser

  @data_dir Parser.data_dir()
  @known_properties_path Path.join(@data_dir, "css_properties.txt")
  @external_resource @known_properties_path

  @known_properties_list @known_properties_path
                         |> File.read!()
                         |> String.split("\n", trim: true)
                         |> Enum.reject(&String.starts_with?(&1, "#"))

  @known_properties MapSet.new(@known_properties_list)

  @spec known_properties() :: MapSet.t(String.t())
  def known_properties, do: @known_properties

  @spec known?(String.t()) :: boolean()
  def known?(<<"--", _rest::binary>>), do: true

  for property <- @known_properties_list do
    def known?(unquote(property)), do: true
  end

  def known?(_), do: false
end
