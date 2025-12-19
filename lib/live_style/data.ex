defmodule LiveStyle.Data do
  @moduledoc """
  Compile-time data loading for LiveStyle.

  This module loads and caches data from text files at compile time,
  making it available as module attributes for efficient runtime access.

  Uses `@external_resource` tracking for automatic recompilation when
  data files change (like the unicode library).
  """

  alias LiveStyle.Data.Parser

  # Track all data files for automatic recompilation
  @data_dir Parser.data_dir()

  @property_priorities_path Path.join(@data_dir, "property_priorities.txt")
  @external_resource @property_priorities_path

  @pseudo_priorities_path Path.join(@data_dir, "pseudo_priorities.txt")
  @external_resource @pseudo_priorities_path

  @unitless_properties_path Path.join(@data_dir, "unitless_properties.txt")
  @external_resource @unitless_properties_path

  @time_properties_path Path.join(@data_dir, "time_properties.txt")
  @external_resource @time_properties_path

  @shorthand_properties_path Path.join(@data_dir, "shorthand_properties.txt")
  @external_resource @shorthand_properties_path

  @disallowed_shorthands_path Path.join(@data_dir, "disallowed_shorthands.txt")
  @external_resource @disallowed_shorthands_path

  @rtl_value_properties_path Path.join(@data_dir, "rtl_value_properties.txt")
  @external_resource @rtl_value_properties_path

  @position_try_properties_path Path.join(@data_dir, "position_try_properties.txt")
  @external_resource @position_try_properties_path

  @logical_properties_path Path.join(@data_dir, "logical_properties.txt")
  @external_resource @logical_properties_path

  @logical_values_path Path.join(@data_dir, "logical_values.txt")
  @external_resource @logical_values_path

  @keep_shorthands_expansions_path Path.join(@data_dir, "keep_shorthands_expansions.txt")
  @external_resource @keep_shorthands_expansions_path

  @expand_to_longhands_expansions_path Path.join(@data_dir, "expand_to_longhands_expansions.txt")
  @external_resource @expand_to_longhands_expansions_path

  # Load all data at compile time
  @property_priorities Parser.property_priorities()
  @pseudo_priorities Parser.pseudo_priorities()
  @unitless_properties Parser.unitless_properties()
  @time_properties Parser.time_properties()
  @shorthand_properties Parser.shorthand_properties()
  @disallowed_shorthands Parser.disallowed_shorthands()
  @disallowed_shorthands_with_messages Parser.disallowed_shorthands_with_messages()
  @rtl_value_properties Parser.rtl_value_properties()
  @position_try_properties Parser.position_try_properties()

  # Logical properties - split into LTR and RTL maps
  {ltr, rtl} = Parser.logical_properties()
  @logical_to_ltr ltr
  @logical_to_rtl rtl

  # Logical values - split into LTR and RTL maps
  {val_ltr, val_rtl} = Parser.logical_values()
  @logical_value_to_ltr val_ltr
  @logical_value_to_rtl val_rtl

  # Derive property priority tiers from @property_priorities (single source of truth)
  # This eliminates duplication and ensures consistency with data files
  @shorthands_of_shorthands @property_priorities
                            |> Enum.filter(fn {_prop, category} ->
                              category == :shorthands_of_shorthands
                            end)
                            |> Enum.map(fn {prop, _} -> prop end)
                            |> MapSet.new()

  @shorthands_of_longhands @property_priorities
                           |> Enum.filter(fn {_prop, category} ->
                             category == :shorthands_of_longhands
                           end)
                           |> Enum.map(fn {prop, _} -> prop end)
                           |> MapSet.new()

  @longhand_physical @property_priorities
                     |> Enum.filter(fn {_prop, category} -> category == :longhand_physical end)
                     |> Enum.map(fn {prop, _} -> prop end)
                     |> MapSet.new()

  # Public accessors
  def property_priorities, do: @property_priorities
  def pseudo_priorities, do: @pseudo_priorities
  def unitless_properties, do: @unitless_properties
  def time_properties, do: @time_properties
  def shorthand_properties, do: @shorthand_properties
  def disallowed_shorthands, do: @disallowed_shorthands
  def disallowed_shorthands_with_messages, do: @disallowed_shorthands_with_messages
  def rtl_value_properties, do: @rtl_value_properties
  def position_try_properties, do: @position_try_properties
  def logical_to_ltr, do: @logical_to_ltr
  def logical_to_rtl, do: @logical_to_rtl
  def logical_value_to_ltr, do: @logical_value_to_ltr
  def logical_value_to_rtl, do: @logical_value_to_rtl
  def shorthands_of_shorthands, do: @shorthands_of_shorthands
  def shorthands_of_longhands, do: @shorthands_of_longhands
  def longhand_physical, do: @longhand_physical

  # KeepShorthands strategy expansions
  @keep_shorthands_expansions Parser.keep_shorthands_expansions()
  def keep_shorthands_expansions, do: @keep_shorthands_expansions

  # ExpandToLonghands strategy expansions
  @expand_to_longhands_expansions Parser.expand_to_longhands_expansions()
  def expand_to_longhands_expansions, do: @expand_to_longhands_expansions
end
