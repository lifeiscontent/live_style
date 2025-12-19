defmodule LiveStyle.Shorthand do
  @moduledoc """
  CSS shorthand property expansion.

  This module handles expanding CSS shorthand properties to their constituent longhand
  properties. It follows StyleX's `application-order.js` pattern where shorthands are
  kept but conflicting longhands are reset to `nil` to ensure deterministic styling.

  Uses compile-time generated function clauses for optimized expansion lookups.
  Simple expansions are generated from data/simple_expansions.txt.
  """

  alias LiveStyle.Data
  alias LiveStyle.Value

  # Load shorthand expansions at compile time
  @shorthand_expansions Data.shorthand_expansions()
  @simple_expansions Data.simple_expansions()

  # These are simple mappings like:
  #   expand_margin_block_start(value) -> [{:margin_top, value}]
  #   expand_gap(value) -> [{:gap, value}, {:row_gap, nil}, {:column_gap, nil}]
  for {func_name, props} <- @simple_expansions do
    @doc false
    def unquote(func_name)(var!(value)) do
      unquote(
        for {prop, type} <- props do
          case type do
            :value -> {prop, Macro.var(:value, nil)}
            nil -> {prop, nil}
          end
        end
      )
    end
  end

  # Generate function clauses for expansion lookup
  # This turns Map.get into pattern-matched function dispatch
  for {property, expansion_fn} <- @shorthand_expansions do
    defp get_expansion(unquote(property)), do: unquote(expansion_fn)
  end

  defp get_expansion(_), do: nil

  def expand(property, value) do
    css_property = Value.to_css_property(property)

    case get_expansion(css_property) do
      nil -> [{property, value}]
      expansion_fn -> apply(__MODULE__, expansion_fn, [value])
    end
  end

  def shorthand_expansions, do: @shorthand_expansions

  def get_longhand_properties("margin"),
    do: [:margin_top, :margin_right, :margin_bottom, :margin_left]

  def get_longhand_properties("padding"),
    do: [:padding_top, :padding_right, :padding_bottom, :padding_left]

  def get_longhand_properties("gap"), do: [:row_gap, :column_gap]
  def get_longhand_properties("overflow"), do: [:overflow_x, :overflow_y]

  def get_longhand_properties("border-radius") do
    [
      :border_top_left_radius,
      :border_top_right_radius,
      :border_bottom_right_radius,
      :border_bottom_left_radius
    ]
  end

  def get_longhand_properties("border-width"),
    do: [:border_top_width, :border_right_width, :border_bottom_width, :border_left_width]

  def get_longhand_properties("border-style"),
    do: [:border_top_style, :border_right_style, :border_bottom_style, :border_left_style]

  def get_longhand_properties("border-color"),
    do: [:border_top_color, :border_right_color, :border_bottom_color, :border_left_color]

  def get_longhand_properties("inset"), do: [:top, :right, :bottom, :left]
  def get_longhand_properties("margin-block"), do: [:margin_top, :margin_bottom]
  def get_longhand_properties("margin-inline"), do: [:margin_left, :margin_right]
  def get_longhand_properties("padding-block"), do: [:padding_top, :padding_bottom]
  def get_longhand_properties("padding-inline"), do: [:padding_left, :padding_right]

  def get_longhand_properties("list-style"),
    do: [:list_style_type, :list_style_position, :list_style_image]

  def get_longhand_properties(_), do: []

  def expand_to_longhands(css_property, value) when is_binary(value) do
    {clean_value, important} = extract_important(value)
    do_expand_to_longhands(css_property, value, clean_value, important)
  end

  defp extract_important(value) do
    if String.ends_with?(value, "!important") do
      {String.trim(String.replace(value, "!important", "")), " !important"}
    else
      {value, ""}
    end
  end

  defp do_expand_to_longhands("margin", _value, clean_value, important) do
    expand_4_value_shorthand(
      clean_value,
      [:margin_top, :margin_right, :margin_bottom, :margin_left],
      important
    )
  end

  defp do_expand_to_longhands("padding", _value, clean_value, important) do
    expand_4_value_shorthand(
      clean_value,
      [:padding_top, :padding_right, :padding_bottom, :padding_left],
      important
    )
  end

  defp do_expand_to_longhands("gap", _value, clean_value, important),
    do: expand_2_value_shorthand(clean_value, [:row_gap, :column_gap], important)

  defp do_expand_to_longhands("overflow", _value, clean_value, important),
    do: expand_2_value_shorthand(clean_value, [:overflow_x, :overflow_y], important)

  defp do_expand_to_longhands("border-radius", _value, clean_value, important),
    do: expand_border_radius_to_longhands(clean_value, important)

  defp do_expand_to_longhands("border-width", _value, clean_value, important) do
    expand_4_value_shorthand(
      clean_value,
      [:border_top_width, :border_right_width, :border_bottom_width, :border_left_width],
      important
    )
  end

  defp do_expand_to_longhands("border-style", _value, clean_value, important) do
    expand_4_value_shorthand(
      clean_value,
      [:border_top_style, :border_right_style, :border_bottom_style, :border_left_style],
      important
    )
  end

  defp do_expand_to_longhands("border-color", _value, clean_value, important) do
    expand_4_value_shorthand(
      clean_value,
      [:border_top_color, :border_right_color, :border_bottom_color, :border_left_color],
      important
    )
  end

  defp do_expand_to_longhands("inset", _value, clean_value, important),
    do: expand_4_value_shorthand(clean_value, [:top, :right, :bottom, :left], important)

  defp do_expand_to_longhands("margin-block", _value, clean_value, important),
    do: expand_2_value_shorthand(clean_value, [:margin_top, :margin_bottom], important)

  defp do_expand_to_longhands("margin-inline", _value, clean_value, important),
    do: expand_2_value_shorthand(clean_value, [:margin_left, :margin_right], important)

  defp do_expand_to_longhands("padding-block", _value, clean_value, important),
    do: expand_2_value_shorthand(clean_value, [:padding_top, :padding_bottom], important)

  defp do_expand_to_longhands("padding-inline", _value, clean_value, important),
    do: expand_2_value_shorthand(clean_value, [:padding_left, :padding_right], important)

  defp do_expand_to_longhands("list-style", _value, clean_value, important),
    do: expand_list_style_to_longhands(clean_value, important)

  defp do_expand_to_longhands(css_property, value, _clean_value, _important),
    do: [{String.to_atom(String.replace(css_property, "-", "_")), value}]

  def split_css_value(value) when is_binary(value) do
    trimmed = String.trim(value)

    {base_value, important?} =
      if String.ends_with?(String.downcase(trimmed), "!important") do
        {String.slice(trimmed, 0, String.length(trimmed) - 10) |> String.trim(), true}
      else
        {trimmed, false}
      end

    parts = do_split_css_value(base_value, [], "", 0)
    if important?, do: Enum.map(parts, &(&1 <> " !important")), else: parts
  end

  def split_css_value(value), do: [value]

  # Margin expansions
  def expand_margin(value),
    do: [
      {:margin, value},
      {:margin_inline, nil},
      {:margin_inline_start, nil},
      {:margin_left, nil},
      {:margin_inline_end, nil},
      {:margin_right, nil},
      {:margin_block, nil},
      {:margin_top, nil},
      {:margin_bottom, nil}
    ]

  def expand_margin_horizontal(value),
    do: [
      {:margin_inline, value},
      {:margin_inline_start, nil},
      {:margin_left, nil},
      {:margin_inline_end, nil},
      {:margin_right, nil}
    ]

  def expand_margin_vertical(value),
    do: [{:margin_block, value}, {:margin_top, nil}, {:margin_bottom, nil}]

  def expand_margin_start(value),
    do: [{:margin_inline_start, value}, {:margin_left, nil}, {:margin_right, nil}]

  def expand_margin_end(value),
    do: [{:margin_inline_end, value}, {:margin_left, nil}, {:margin_right, nil}]

  def expand_margin_left(value),
    do: [{:margin_left, value}, {:margin_inline_start, nil}, {:margin_inline_end, nil}]

  def expand_margin_right(value),
    do: [{:margin_right, value}, {:margin_inline_start, nil}, {:margin_inline_end, nil}]

  # expand_margin_block_start and expand_margin_block_end are generated from data file

  # Padding expansions
  def expand_padding(value),
    do: [
      {:padding, value},
      {:padding_inline, nil},
      {:padding_start, nil},
      {:padding_left, nil},
      {:padding_end, nil},
      {:padding_right, nil},
      {:padding_block, nil},
      {:padding_top, nil},
      {:padding_bottom, nil}
    ]

  def expand_padding_horizontal(value),
    do: [
      {:padding_inline, value},
      {:padding_start, nil},
      {:padding_left, nil},
      {:padding_end, nil},
      {:padding_right, nil}
    ]

  def expand_padding_vertical(value),
    do: [{:padding_block, value}, {:padding_top, nil}, {:padding_bottom, nil}]

  def expand_padding_start(value),
    do: [{:padding_inline_start, value}, {:padding_left, nil}, {:padding_right, nil}]

  def expand_padding_end(value),
    do: [{:padding_inline_end, value}, {:padding_left, nil}, {:padding_right, nil}]

  def expand_padding_left(value),
    do: [{:padding_left, value}, {:padding_inline_start, nil}, {:padding_inline_end, nil}]

  def expand_padding_right(value),
    do: [{:padding_right, value}, {:padding_inline_start, nil}, {:padding_inline_end, nil}]

  # expand_padding_block_start, expand_padding_block_end, expand_gap, expand_overflow,
  # expand_grid_row_gap, expand_grid_column_gap, expand_overflow_block, expand_overflow_inline
  # are all generated from data file

  # Border radius
  def expand_border_radius(value),
    do: [
      {:border_radius, value},
      {:border_start_start_radius, nil},
      {:border_start_end_radius, nil},
      {:border_end_start_radius, nil},
      {:border_end_end_radius, nil},
      {:border_top_left_radius, nil},
      {:border_top_right_radius, nil},
      {:border_bottom_left_radius, nil},
      {:border_bottom_right_radius, nil}
    ]

  # expand_border_top_start_radius, expand_border_top_end_radius,
  # expand_border_bottom_start_radius, expand_border_bottom_end_radius
  # are generated from data file

  def expand_border_start_start_radius(value),
    do: [
      {:border_start_start_radius, value},
      {:border_top_left_radius, nil},
      {:border_top_right_radius, nil}
    ]

  def expand_border_start_end_radius(value),
    do: [
      {:border_start_end_radius, value},
      {:border_top_left_radius, nil},
      {:border_top_right_radius, nil}
    ]

  def expand_border_end_start_radius(value),
    do: [
      {:border_end_start_radius, value},
      {:border_bottom_left_radius, nil},
      {:border_bottom_right_radius, nil}
    ]

  def expand_border_end_end_radius(value),
    do: [
      {:border_end_end_radius, value},
      {:border_bottom_left_radius, nil},
      {:border_bottom_right_radius, nil}
    ]

  def expand_border_top_left_radius(value),
    do: [
      {:border_top_left_radius, value},
      {:border_start_start_radius, nil},
      {:border_start_end_radius, nil}
    ]

  def expand_border_top_right_radius(value),
    do: [
      {:border_top_right_radius, value},
      {:border_start_start_radius, nil},
      {:border_start_end_radius, nil}
    ]

  def expand_border_bottom_left_radius(value),
    do: [
      {:border_bottom_left_radius, value},
      {:border_end_start_radius, nil},
      {:border_end_end_radius, nil}
    ]

  def expand_border_bottom_right_radius(value),
    do: [
      {:border_bottom_right_radius, value},
      {:border_end_start_radius, nil},
      {:border_end_end_radius, nil}
    ]

  # Border expansions
  def expand_border(value),
    do: [
      {:border, value},
      {:border_width, nil},
      {:border_inline_width, nil},
      {:border_inline_start_width, nil},
      {:border_left_width, nil},
      {:border_inline_end_width, nil},
      {:border_right_width, nil},
      {:border_block_width, nil},
      {:border_top_width, nil},
      {:border_bottom_width, nil},
      {:border_style, nil},
      {:border_inline_style, nil},
      {:border_inline_start_style, nil},
      {:border_left_style, nil},
      {:border_inline_end_style, nil},
      {:border_right_style, nil},
      {:border_block_style, nil},
      {:border_top_style, nil},
      {:border_bottom_style, nil},
      {:border_color, nil},
      {:border_inline_color, nil},
      {:border_inline_start_color, nil},
      {:border_left_color, nil},
      {:border_inline_end_color, nil},
      {:border_right_color, nil},
      {:border_block_color, nil},
      {:border_top_color, nil},
      {:border_bottom_color, nil}
    ]

  def expand_border_color(value),
    do: [
      {:border_color, value},
      {:border_inline_color, nil},
      {:border_inline_start_color, nil},
      {:border_left_color, nil},
      {:border_inline_end_color, nil},
      {:border_right_color, nil},
      {:border_block_color, nil},
      {:border_top_color, nil},
      {:border_bottom_color, nil}
    ]

  def expand_border_style(value),
    do: [
      {:border_style, value},
      {:border_inline_style, nil},
      {:border_inline_start_style, nil},
      {:border_left_style, nil},
      {:border_inline_end_style, nil},
      {:border_right_style, nil},
      {:border_block_style, nil},
      {:border_top_style, nil},
      {:border_bottom_style, nil}
    ]

  def expand_border_width(value),
    do: [
      {:border_width, value},
      {:border_inline_width, nil},
      {:border_inline_start_width, nil},
      {:border_left_width, nil},
      {:border_inline_end_width, nil},
      {:border_right_width, nil},
      {:border_block_width, nil},
      {:border_top_width, nil},
      {:border_bottom_width, nil}
    ]

  def expand_border_horizontal(value),
    do: [
      {:border_inline, value},
      {:border_inline_width, nil},
      {:border_inline_start_width, nil},
      {:border_left_width, nil},
      {:border_inline_end_width, nil},
      {:border_right_width, nil},
      {:border_inline_style, nil},
      {:border_inline_start_style, nil},
      {:border_left_style, nil},
      {:border_inline_end_style, nil},
      {:border_right_style, nil},
      {:border_inline_color, nil},
      {:border_inline_start_color, nil},
      {:border_left_color, nil},
      {:border_inline_end_color, nil},
      {:border_right_color, nil}
    ]

  def expand_border_vertical(value),
    do: [
      {:border_block, value},
      {:border_block_width, nil},
      {:border_top_width, nil},
      {:border_bottom_width, nil},
      {:border_block_style, nil},
      {:border_top_style, nil},
      {:border_bottom_style, nil},
      {:border_block_color, nil},
      {:border_top_color, nil},
      {:border_bottom_color, nil}
    ]

  # expand_border_block_start, expand_border_block_end,
  # expand_border_inline_start, expand_border_inline_end
  # are generated from data file

  def expand_border_top(value),
    do: [
      {:border_top, value},
      {:border_top_width, nil},
      {:border_top_style, nil},
      {:border_top_color, nil}
    ]

  def expand_border_bottom(value),
    do: [
      {:border_bottom, value},
      {:border_bottom_width, nil},
      {:border_bottom_style, nil},
      {:border_bottom_color, nil}
    ]

  def expand_border_left_shorthand(value),
    do: [
      {:border_left, value},
      {:border_left_width, nil},
      {:border_left_style, nil},
      {:border_left_color, nil}
    ]

  def expand_border_right_shorthand(value),
    do: [
      {:border_right, value},
      {:border_right_width, nil},
      {:border_right_style, nil},
      {:border_right_color, nil}
    ]

  def expand_border_inline_start_shorthand(value),
    do: [
      {:border_inline_start, value},
      {:border_inline_start_width, nil},
      {:border_left_width, nil},
      {:border_right_width, nil},
      {:border_inline_start_style, nil},
      {:border_left_style, nil},
      {:border_right_style, nil},
      {:border_inline_start_color, nil},
      {:border_left_color, nil},
      {:border_right_color, nil}
    ]

  def expand_border_inline_end_shorthand(value),
    do: [
      {:border_inline_end, value},
      {:border_inline_end_width, nil},
      {:border_left_width, nil},
      {:border_right_width, nil},
      {:border_inline_end_style, nil},
      {:border_left_style, nil},
      {:border_right_style, nil},
      {:border_inline_end_color, nil},
      {:border_left_color, nil},
      {:border_right_color, nil}
    ]

  # Border width
  def expand_border_block_width(value),
    do: [{:border_block_width, value}, {:border_top_width, nil}, {:border_bottom_width, nil}]

  # expand_border_block_start_width, expand_border_block_end_width are generated from data file

  def expand_border_inline_width(value),
    do: [
      {:border_inline_width, value},
      {:border_inline_start_width, nil},
      {:border_left_width, nil},
      {:border_inline_end_width, nil},
      {:border_right_width, nil}
    ]

  # expand_border_inline_start_width, expand_border_inline_end_width are generated from data file

  def expand_border_inline_start_width_with_resets(value),
    do: [
      {:border_inline_start_width, value},
      {:border_left_width, nil},
      {:border_right_width, nil}
    ]

  def expand_border_inline_end_width_with_resets(value),
    do: [{:border_inline_end_width, value}, {:border_left_width, nil}, {:border_right_width, nil}]

  def expand_border_left_width(value),
    do: [
      {:border_left_width, value},
      {:border_inline_start_width, nil},
      {:border_inline_end_width, nil}
    ]

  def expand_border_right_width(value),
    do: [
      {:border_right_width, value},
      {:border_inline_start_width, nil},
      {:border_inline_end_width, nil}
    ]

  # Border style
  def expand_border_block_style(value),
    do: [{:border_block_style, value}, {:border_top_style, nil}, {:border_bottom_style, nil}]

  # expand_border_block_start_style, expand_border_block_end_style are generated from data file

  def expand_border_inline_style(value),
    do: [
      {:border_inline_style, value},
      {:border_inline_start_style, nil},
      {:border_left_style, nil},
      {:border_inline_end_style, nil},
      {:border_right_style, nil}
    ]

  # expand_border_inline_start_style, expand_border_inline_end_style are generated from data file

  def expand_border_inline_start_style_with_resets(value),
    do: [
      {:border_inline_start_style, value},
      {:border_left_style, nil},
      {:border_right_style, nil}
    ]

  def expand_border_inline_end_style_with_resets(value),
    do: [{:border_inline_end_style, value}, {:border_left_style, nil}, {:border_right_style, nil}]

  def expand_border_left_style(value),
    do: [
      {:border_left_style, value},
      {:border_inline_start_style, nil},
      {:border_inline_end_style, nil}
    ]

  def expand_border_right_style(value),
    do: [
      {:border_right_style, value},
      {:border_inline_start_style, nil},
      {:border_inline_end_style, nil}
    ]

  # Border color
  def expand_border_block_color(value),
    do: [{:border_block_color, value}, {:border_top_color, nil}, {:border_bottom_color, nil}]

  # expand_border_block_start_color, expand_border_block_end_color are generated from data file

  def expand_border_inline_color(value),
    do: [
      {:border_inline_color, value},
      {:border_inline_start_color, nil},
      {:border_left_color, nil},
      {:border_inline_end_color, nil},
      {:border_right_color, nil}
    ]

  # expand_border_inline_start_color, expand_border_inline_end_color are generated from data file

  def expand_border_inline_start_color_with_resets(value),
    do: [
      {:border_inline_start_color, value},
      {:border_left_color, nil},
      {:border_right_color, nil}
    ]

  def expand_border_inline_end_color_with_resets(value),
    do: [{:border_inline_end_color, value}, {:border_left_color, nil}, {:border_right_color, nil}]

  def expand_border_left_color(value),
    do: [
      {:border_left_color, value},
      {:border_inline_start_color, nil},
      {:border_inline_end_color, nil}
    ]

  def expand_border_right_color(value),
    do: [
      {:border_right_color, value},
      {:border_inline_start_color, nil},
      {:border_inline_end_color, nil}
    ]

  # Inset expansions
  def expand_inset(value),
    do: [
      {:inset, value},
      {:inset_inline, nil},
      {:inset_inline_start, nil},
      {:inset_inline_end, nil},
      {:left, nil},
      {:right, nil},
      {:inset_block, nil},
      {:top, nil},
      {:bottom, nil}
    ]

  def expand_inset_inline(value),
    do: [
      {:inset_inline, value},
      {:inset_inline_start, nil},
      {:inset_inline_end, nil},
      {:left, nil},
      {:right, nil}
    ]

  # expand_inset_block, expand_start, expand_end are generated from data file

  def expand_left(value),
    do: [{:left, value}, {:inset_inline_start, nil}, {:inset_inline_end, nil}]

  def expand_right(value),
    do: [{:right, value}, {:inset_inline_start, nil}, {:inset_inline_end, nil}]

  # expand_inset_block_start, expand_inset_block_end, expand_block_size, expand_inline_size,
  # expand_min_block_size, expand_min_inline_size, expand_max_block_size, expand_max_inline_size
  # are generated from data file

  # List style
  def expand_list_style(value),
    do: [
      {:list_style, value},
      {:list_style_image, nil},
      {:list_style_position, nil},
      {:list_style_type, nil}
    ]

  # Flex
  def expand_flex(value),
    do: [{:flex, value}, {:flex_grow, nil}, {:flex_shrink, nil}, {:flex_basis, nil}]

  def expand_flex_flow(value),
    do: [{:flex_flow, value}, {:flex_direction, nil}, {:flex_wrap, nil}]

  # Grid
  def expand_grid(value),
    do: [
      {:grid, value},
      {:grid_template, nil},
      {:grid_template_areas, nil},
      {:grid_template_columns, nil},
      {:grid_template_rows, nil},
      {:grid_auto_rows, nil},
      {:grid_auto_columns, nil},
      {:grid_auto_flow, nil}
    ]

  def expand_grid_template(value),
    do: [
      {:grid_template, value},
      {:grid_template_areas, nil},
      {:grid_template_columns, nil},
      {:grid_template_rows, nil}
    ]

  def expand_grid_area(value),
    do: [
      {:grid_area, value},
      {:grid_row, nil},
      {:grid_row_start, nil},
      {:grid_row_end, nil},
      {:grid_column, nil},
      {:grid_column_start, nil},
      {:grid_column_end, nil}
    ]

  def expand_grid_row(value),
    do: [{:grid_row, value}, {:grid_row_start, nil}, {:grid_row_end, nil}]

  def expand_grid_column(value),
    do: [{:grid_column, value}, {:grid_column_start, nil}, {:grid_column_end, nil}]

  # Animation and transition
  def expand_animation(value),
    do: [
      {:animation, value},
      {:animation_composition, nil},
      {:animation_name, nil},
      {:animation_duration, nil},
      {:animation_timing_function, nil},
      {:animation_delay, nil},
      {:animation_iteration_count, nil},
      {:animation_direction, nil},
      {:animation_fill_mode, nil},
      {:animation_play_state, nil},
      {:animation_range, nil},
      {:animation_range_end, nil},
      {:animation_range_start, nil},
      {:animation_timeline, nil}
    ]

  def expand_animation_range(value),
    do: [{:animation_range, value}, {:animation_range_end, nil}, {:animation_range_start, nil}]

  def expand_transition(value),
    do: [
      {:transition, value},
      {:transition_behavior, nil},
      {:transition_delay, nil},
      {:transition_duration, nil},
      {:transition_property, nil},
      {:transition_timing_function, nil}
    ]

  # Background
  def expand_background(value),
    do: [
      {:background, value},
      {:background_attachment, nil},
      {:background_clip, nil},
      {:background_color, nil},
      {:background_image, nil},
      {:background_origin, nil},
      {:background_position, nil},
      {:background_position_x, nil},
      {:background_position_y, nil},
      {:background_repeat, nil},
      {:background_size, nil}
    ]

  def expand_background_position(value),
    do: [
      {:background_position, value},
      {:background_position_x, nil},
      {:background_position_y, nil}
    ]

  # Text
  def expand_text_decoration(value),
    do: [
      {:text_decoration, value},
      {:text_decoration_color, nil},
      {:text_decoration_line, nil},
      {:text_decoration_style, nil},
      {:text_decoration_thickness, nil}
    ]

  def expand_text_emphasis(value),
    do: [{:text_emphasis, value}, {:text_emphasis_color, nil}, {:text_emphasis_style, nil}]

  # Other shorthands
  def expand_outline(value),
    do: [
      {:outline, value},
      {:outline_color, nil},
      {:outline_offset, nil},
      {:outline_style, nil},
      {:outline_width, nil}
    ]

  # expand_columns is generated from data file

  def expand_column_rule(value),
    do: [
      {:column_rule, value},
      {:column_rule_color, nil},
      {:column_rule_style, nil},
      {:column_rule_width, nil}
    ]

  def expand_container(value),
    do: [{:container, value}, {:container_name, nil}, {:container_type, nil}]

  def expand_font(value),
    do: [
      {:font, value},
      {:font_family, nil},
      {:font_size, nil},
      {:font_stretch, nil},
      {:font_style, nil},
      {:font_variant, nil},
      {:font_variant_alternates, nil},
      {:font_variant_caps, nil},
      {:font_variant_east_asian, nil},
      {:font_variant_emoji, nil},
      {:font_variant_ligatures, nil},
      {:font_variant_numeric, nil},
      {:font_variant_position, nil},
      {:font_weight, nil},
      {:line_height, nil}
    ]

  def expand_font_variant(value),
    do: [
      {:font_variant, value},
      {:font_variant_alternates, nil},
      {:font_variant_caps, nil},
      {:font_variant_east_asian, nil},
      {:font_variant_emoji, nil},
      {:font_variant_ligatures, nil},
      {:font_variant_numeric, nil},
      {:font_variant_position, nil}
    ]

  def expand_mask(value),
    do: [
      {:mask, value},
      {:mask_clip, nil},
      {:mask_composite, nil},
      {:mask_image, nil},
      {:mask_mode, nil},
      {:mask_origin, nil},
      {:mask_position, nil},
      {:mask_repeat, nil},
      {:mask_size, nil}
    ]

  def expand_mask_border(value),
    do: [
      {:mask_border, value},
      {:mask_border_mode, nil},
      {:mask_border_outset, nil},
      {:mask_border_repeat, nil},
      {:mask_border_slice, nil},
      {:mask_border_source, nil},
      {:mask_border_width, nil}
    ]

  def expand_border_image(value),
    do: [
      {:border_image, value},
      {:border_image_outset, nil},
      {:border_image_repeat, nil},
      {:border_image_slice, nil},
      {:border_image_source, nil},
      {:border_image_width, nil}
    ]

  def expand_offset(value),
    do: [
      {:offset, value},
      {:offset_anchor, nil},
      {:offset_distance, nil},
      {:offset_path, nil},
      {:offset_position, nil},
      {:offset_rotate, nil}
    ]

  def expand_place_content(value),
    do: [{:place_content, value}, {:align_content, nil}, {:justify_content, nil}]

  def expand_place_items(value),
    do: [{:place_items, value}, {:align_items, nil}, {:justify_items, nil}]

  def expand_place_self(value),
    do: [{:place_self, value}, {:align_self, nil}, {:justify_self, nil}]

  # Scroll margin
  def expand_scroll_margin(value),
    do: [
      {:scroll_margin, value},
      {:scroll_margin_block, nil},
      {:scroll_margin_top, nil},
      {:scroll_margin_bottom, nil},
      {:scroll_margin_inline, nil},
      {:scroll_margin_inline_start, nil},
      {:scroll_margin_inline_end, nil},
      {:scroll_margin_left, nil},
      {:scroll_margin_right, nil}
    ]

  def expand_scroll_margin_block(value),
    do: [{:scroll_margin_block, value}, {:scroll_margin_top, nil}, {:scroll_margin_bottom, nil}]

  def expand_scroll_margin_inline(value),
    do: [
      {:scroll_margin_inline, value},
      {:scroll_margin_inline_start, nil},
      {:scroll_margin_inline_end, nil},
      {:scroll_margin_left, nil},
      {:scroll_margin_right, nil}
    ]

  def expand_scroll_margin_inline_start(value),
    do: [
      {:scroll_margin_inline_start, value},
      {:scroll_margin_left, nil},
      {:scroll_margin_right, nil}
    ]

  def expand_scroll_margin_inline_end(value),
    do: [
      {:scroll_margin_inline_end, value},
      {:scroll_margin_left, nil},
      {:scroll_margin_right, nil}
    ]

  def expand_scroll_margin_left(value),
    do: [
      {:scroll_margin_left, value},
      {:scroll_margin_inline_start, nil},
      {:scroll_margin_inline_end, nil}
    ]

  def expand_scroll_margin_right(value),
    do: [
      {:scroll_margin_right, value},
      {:scroll_margin_inline_start, nil},
      {:scroll_margin_inline_end, nil}
    ]

  # expand_scroll_margin_block_start, expand_scroll_margin_block_end are generated from data file

  # Scroll padding
  def expand_scroll_padding(value),
    do: [
      {:scroll_padding, value},
      {:scroll_padding_block, nil},
      {:scroll_padding_top, nil},
      {:scroll_padding_bottom, nil},
      {:scroll_padding_inline, nil},
      {:scroll_padding_inline_start, nil},
      {:scroll_padding_inline_end, nil},
      {:scroll_padding_left, nil},
      {:scroll_padding_right, nil}
    ]

  def expand_scroll_padding_block(value),
    do: [
      {:scroll_padding_block, value},
      {:scroll_padding_top, nil},
      {:scroll_padding_bottom, nil}
    ]

  def expand_scroll_padding_inline(value),
    do: [
      {:scroll_padding_inline, value},
      {:scroll_padding_inline_start, nil},
      {:scroll_padding_inline_end, nil},
      {:scroll_padding_left, nil},
      {:scroll_padding_right, nil}
    ]

  def expand_scroll_padding_inline_start(value),
    do: [
      {:scroll_padding_inline_start, value},
      {:scroll_padding_left, nil},
      {:scroll_padding_right, nil}
    ]

  def expand_scroll_padding_inline_end(value),
    do: [
      {:scroll_padding_inline_end, value},
      {:scroll_padding_left, nil},
      {:scroll_padding_right, nil}
    ]

  def expand_scroll_padding_left(value),
    do: [
      {:scroll_padding_left, value},
      {:scroll_padding_inline_start, nil},
      {:scroll_padding_inline_end, nil}
    ]

  def expand_scroll_padding_right(value),
    do: [
      {:scroll_padding_right, value},
      {:scroll_padding_inline_start, nil},
      {:scroll_padding_inline_end, nil}
    ]

  # expand_scroll_padding_block_start, expand_scroll_padding_block_end are generated from data file

  # Scroll snap and timeline
  def expand_scroll_snap_type(value),
    do: [{:scroll_snap_type, value}, {:scroll_snap_type_x, nil}, {:scroll_snap_type_y, nil}]

  def expand_scroll_timeline(value),
    do: [{:scroll_timeline, value}, {:scroll_timeline_name, nil}, {:scroll_timeline_axis, nil}]

  # Overscroll and contain
  def expand_overscroll_behavior(value) do
    parts = split_css_value(value)

    [x, y] =
      case parts do
        [single] -> [single, single]
        [a, b] -> [a, b]
        _ -> [nil, nil]
      end

    [{:overscroll_behavior_x, x}, {:overscroll_behavior_y, y}]
  end

  def expand_contain_intrinsic_size(nil),
    do: [{:contain_intrinsic_width, nil}, {:contain_intrinsic_height, nil}]

  def expand_contain_intrinsic_size(value) when is_binary(value) do
    # contain-intrinsic-size can have "auto" prefix that combines with the size value
    # Examples:
    # - "100px 200px" -> width: 100px, height: 200px
    # - "auto 100px 200px" -> width: auto 100px, height: 200px
    # - "auto 100px auto 200px" -> width: auto 100px, height: auto 200px
    # - "100px" -> width: 100px, height: 100px (same for both)
    {width, height} = parse_contain_intrinsic_values(value)
    [{:contain_intrinsic_width, width}, {:contain_intrinsic_height, height}]
  end

  def expand_contain_intrinsic_size(value),
    do: [{:contain_intrinsic_width, value}, {:contain_intrinsic_height, value}]

  defp parse_contain_intrinsic_values(value) do
    parts = split_css_value(value)

    case parts do
      [single] ->
        {single, single}

      [w, h] ->
        {w, h}

      ["auto", size1, size2] ->
        # "auto 100px 200px" -> width: "auto 100px", height: "200px"
        {"auto #{size1}", size2}

      ["auto", size1, "auto", size2] ->
        # "auto 100px auto 200px" -> width: "auto 100px", height: "auto 200px"
        {"auto #{size1}", "auto #{size2}"}

      [size1, "auto", size2] ->
        # "100px auto 200px" -> width: "100px", height: "auto 200px"
        {size1, "auto #{size2}"}

      _ ->
        # Fallback: use value as-is for both
        {value, value}
    end
  end

  # expand_contain_intrinsic_block_size, expand_contain_intrinsic_inline_size are generated from data file

  defp split_shorthand_value(value) do
    value
    |> String.trim()
    |> do_split_shorthand_value([], "", 0)
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp do_split_shorthand_value("", acc, current, _depth), do: [String.trim(current) | acc]

  defp do_split_shorthand_value(" " <> rest, acc, current, 0),
    do: do_split_shorthand_value(rest, [String.trim(current) | acc], "", 0)

  defp do_split_shorthand_value("(" <> rest, acc, current, depth),
    do: do_split_shorthand_value(rest, acc, current <> "(", depth + 1)

  defp do_split_shorthand_value(")" <> rest, acc, current, depth),
    do: do_split_shorthand_value(rest, acc, current <> ")", max(0, depth - 1))

  defp do_split_shorthand_value(<<char::utf8, rest::binary>>, acc, current, depth),
    do: do_split_shorthand_value(rest, acc, current <> <<char::utf8>>, depth)

  defp do_split_css_value("", acc, current, _depth) do
    case String.trim(current) do
      "" -> Enum.reverse(acc)
      trimmed -> Enum.reverse([trimmed | acc])
    end
  end

  defp do_split_css_value(<<" ", rest::binary>>, acc, current, 0) do
    case String.trim(current) do
      "" -> do_split_css_value(rest, acc, "", 0)
      trimmed -> do_split_css_value(rest, [trimmed | acc], "", 0)
    end
  end

  defp do_split_css_value(<<"(", rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> "(", depth + 1)

  defp do_split_css_value(<<")", rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> ")", max(0, depth - 1))

  defp do_split_css_value(<<char::utf8, rest::binary>>, acc, current, depth),
    do: do_split_css_value(rest, acc, current <> <<char::utf8>>, depth)

  defp expand_4_value_shorthand(value, [top, right, bottom, left], important) do
    parts = split_shorthand_value(value)

    {t, r, b, l} =
      case parts do
        [v] -> {v, v, v, v}
        [v, h] -> {v, h, v, h}
        [t, h, b] -> {t, h, b, h}
        [t, r, b, l] -> {t, r, b, l}
        _ -> {value, value, value, value}
      end

    [
      {top, t <> important},
      {right, r <> important},
      {bottom, b <> important},
      {left, l <> important}
    ]
  end

  defp expand_2_value_shorthand(value, [first, second], important) do
    parts = split_shorthand_value(value)

    {v1, v2} =
      case parts do
        [v] -> {v, v}
        [v1, v2] -> {v1, v2}
        _ -> {value, value}
      end

    [{first, v1 <> important}, {second, v2 <> important}]
  end

  defp expand_border_radius_to_longhands(value, important) do
    props = [
      :border_top_left_radius,
      :border_top_right_radius,
      :border_bottom_right_radius,
      :border_bottom_left_radius
    ]

    if String.contains?(value, "/") do
      expand_border_radius_with_slash(value, props, important)
    else
      expand_4_value_shorthand(value, props, important)
    end
  end

  defp expand_border_radius_with_slash(value, props, important) do
    [h_part, v_part] = String.split(value, "/", parts: 2) |> Enum.map(&String.trim/1)
    h_values = split_shorthand_value(h_part)
    v_values = split_shorthand_value(v_part)
    h4 = expand_to_4(h_values)
    v4 = expand_to_4(v_values)

    Enum.zip(props, Enum.zip(h4, v4))
    |> Enum.map(fn {prop, {h, v}} ->
      combined = combine_radius_values(h, v)
      {prop, combined <> important}
    end)
  end

  defp combine_radius_values(h, h), do: h
  defp combine_radius_values(h, v), do: "#{h} #{v}"

  defp expand_to_4([v]), do: [v, v, v, v]
  defp expand_to_4([v, h]), do: [v, h, v, h]
  defp expand_to_4([t, h, b]), do: [t, h, b, h]
  defp expand_to_4([t, r, b, l]), do: [t, r, b, l]
  defp expand_to_4(v), do: [v, v, v, v]

  defp expand_list_style_to_longhands(value, important) do
    parts = split_shorthand_value(value)

    {type, position, image} =
      Enum.reduce(parts, {nil, nil, nil}, fn part, {t, p, i} ->
        case part do
          <<"url(", _::binary>> -> {t, p, part}
          "none" when i == nil -> {t, p, part}
          "inside" -> {t, part, i}
          "outside" -> {t, part, i}
          _ -> {part, p, i}
        end
      end)

    result = []
    result = if type, do: [{:list_style_type, type <> important} | result], else: result

    result =
      if position, do: [{:list_style_position, position <> important} | result], else: result

    result = if image, do: [{:list_style_image, image <> important} | result], else: result
    Enum.reverse(result)
  end
end
