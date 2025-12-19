defmodule Mix.Tasks.LiveStyle.SetupTests do
  @moduledoc """
  Pre-compiles test files to register LiveStyle modules in the manifest.

  ## Why This Is Needed

  Source files (`.ex`) are compiled by Mix before your app runs, so their LiveStyle
  definitions are in the manifest when needed. Test files (`.exs`) are different -
  they're evaluated by ExUnit at runtime, which can cause race conditions where
  tests start before all test modules have registered their styles.

  This task compiles test files in a subprocess to populate the manifest before
  ExUnit starts, ensuring all LiveStyle definitions are available.

  ## When You Need This

  Only add this task if your tests define LiveStyle modules. For example:

      defmodule MyApp.ComponentTest do
        use ExUnit.Case

        # This module needs to be in the manifest before tests run
        defmodule TestStyles do
          use LiveStyle.Sheet
          css_class :test_button, color: "red"
        end

        test "renders with correct class" do
          # Test uses TestStyles
        end
      end

  If your tests only *use* styles defined in `lib/` (not define new ones), you
  don't need this task.

  ## Setup

  Add this task to your test alias in `mix.exs`:

      defp aliases do
        [
          test: ["live_style.setup_tests", "test"]
        ]
      end

  ## Usage

  The task runs automatically before tests via the alias:

      mix test

  Or run manually:

      mix live_style.setup_tests
  """

  use Mix.Task

  @shortdoc "Pre-compiles test files with LiveStyle modules"

  @impl Mix.Task
  def run(_args) do
    # Ensure the app is compiled first
    Mix.Task.run("compile", [])

    # Find all test files
    test_files =
      Path.wildcard("test/**/*_test.exs")
      |> Enum.sort()

    if test_files == [] do
      Mix.shell().info("No test files found")
    else
      Mix.shell().info("LiveStyle: Pre-compiling #{length(test_files)} test files...")

      # Compile test files in a separate beam process to avoid module conflicts
      # when ExUnit loads them again
      compile_in_subprocess(test_files)

      Mix.shell().info("LiveStyle: Test modules compiled successfully")
    end

    :ok
  end

  defp compile_in_subprocess(test_files) do
    # Build the script to run
    files_str = inspect(test_files)

    script = """
    Code.compiler_options(ignore_module_conflict: true)
    files = #{files_str}
    Kernel.ParallelCompiler.compile(files)
    """

    # Run in a subprocess using mix run
    # This ensures a clean VM where modules won't conflict with ExUnit's loading
    {output, exit_code} =
      System.cmd(
        "mix",
        ["run", "--no-start", "-e", script],
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    if exit_code != 0 do
      Mix.raise("Failed to compile test files:\n#{output}")
    end
  end
end
