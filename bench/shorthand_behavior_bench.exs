# Benchmark for shorthand_behavior modes
#
# Run with: mix run bench/shorthand_behavior_bench.exs
#
# This benchmarks the three shorthand expansion behaviors:
# - :accept_shorthands (default) - Pass through with null resets for cascade control
# - :forbid_shorthands - Pass through, error on disallowed shorthands
# - :flatten_shorthands - Expand shorthands to longhands

# Sample style declarations to benchmark
sample_styles = %{
  # Simple properties (no expansion needed)
  simple: [
    display: "flex",
    color: "blue",
    font_size: "16px"
  ],
  # Shorthand properties that get expanded
  shorthands: [
    margin: "10px 20px 30px 40px",
    padding: "8px 16px",
    gap: "10px 20px",
    border_radius: "4px 8px 12px 16px"
  ],
  # Mixed properties
  mixed: [
    display: "flex",
    margin: "10px 20px",
    padding: "8px",
    color: "red",
    border_radius: "8px",
    gap: "16px"
  ],
  # Conditional styles
  conditional: [
    color: %{
      default: "blue",
      ":hover": "darkblue",
      ":active": "navy"
    },
    margin: %{
      default: "10px",
      "@media (min-width: 768px)": "20px"
    }
  ],
  # Complex realistic component
  realistic: [
    display: "flex",
    align_items: "center",
    justify_content: "center",
    padding: "12px 24px",
    margin: "8px",
    border_radius: "8px",
    background_color: "white",
    color: "black",
    font_size: "14px",
    font_weight: "500",
    gap: "8px",
    cursor: "pointer",
    transition: "all 0.2s ease"
  ]
}

# Function to benchmark style processing for a given behavior
defmodule BenchHelper do
  def process_styles(styles, behavior) do
    Application.put_env(:live_style, :shorthand_behavior, behavior)
    LiveStyle.Storage.clear()

    # Create a unique module name for each invocation
    module_name = :"BenchModule_#{:erlang.unique_integer([:positive])}"

    # Use Code.compile_quoted to compile the style at runtime
    # This simulates what happens during actual compilation
    quoted =
      quote do
        defmodule unquote(module_name) do
          use LiveStyle
          css_rule(:bench_style, unquote(Macro.escape(styles)))
        end
      end

    Code.compile_quoted(quoted)
    manifest = LiveStyle.Storage.read()
    LiveStyle.CSS.generate(manifest)
  end
end

IO.puts("=" |> String.duplicate(70))
IO.puts("LiveStyle Shorthand Behavior Benchmark")
IO.puts("=" |> String.duplicate(70))
IO.puts("")

# Warm up
IO.puts("Warming up...")

Enum.each([:forbid_shorthands, :accept_shorthands, :flatten_shorthands], fn behavior ->
  BenchHelper.process_styles(sample_styles.simple, behavior)
end)

IO.puts("Done warming up.\n")

# Run benchmarks for each style type
Enum.each(sample_styles, fn {style_name, styles} ->
  IO.puts("-" |> String.duplicate(70))
  IO.puts("Benchmarking: #{style_name}")
  IO.puts("-" |> String.duplicate(70))

  Benchee.run(
    %{
      "forbid_shorthands" => fn ->
        BenchHelper.process_styles(styles, :forbid_shorthands)
      end,
      "accept_shorthands" => fn ->
        BenchHelper.process_styles(styles, :accept_shorthands)
      end,
      "flatten_shorthands" => fn ->
        BenchHelper.process_styles(styles, :flatten_shorthands)
      end
    },
    warmup: 1,
    time: 3,
    memory_time: 1,
    print: [
      benchmarking: false,
      configuration: false
    ]
  )

  IO.puts("")
end)

# Reset to default
Application.put_env(:live_style, :shorthand_behavior, :accept_shorthands)
