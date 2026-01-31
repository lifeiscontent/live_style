defmodule LiveStyle.Compiler.ModuleData do
  @moduledoc """
  Per-module data storage for LiveStyle compilation.

  During compilation, each module writes its LiveStyle data to a separate file.
  This eliminates lock contention since each module has its own file.

  After compilation, the `:live_style` compiler reads all module files and
  merges them into a single manifest for CSS generation.

  ## File Structure

      _build/{env}/live_style/{app}/modules/{Module}.etf

  This follows the same pattern as phoenix-colocated.
  """

  @doc """
  Writes module data to a per-module file.

  Called from `__before_compile__` - each module writes its own file,
  no locking needed.
  """
  @spec write(module(), map()) :: :ok
  def write(module, data) when is_atom(module) and is_map(data) do
    path = module_path(module)
    dir = Path.dirname(path)

    File.mkdir_p!(dir)
    File.write!(path, :erlang.term_to_binary(data))
    :ok
  end

  @doc """
  Reads module data from a per-module file.

  Returns `nil` if the file doesn't exist.
  """
  @spec read(module()) :: map() | nil
  def read(module) when is_atom(module) do
    path = module_path(module)

    if File.exists?(path) do
      path
      |> File.read!()
      |> :erlang.binary_to_term()
    else
      nil
    end
  end

  @doc """
  Returns all module data files.

  Used by the compiler to merge all modules into a manifest.
  """
  @spec list_all() :: [{module(), map()}]
  def list_all do
    modules_dir()
    |> File.ls()
    |> case do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".etf"))
        |> Enum.map(fn file ->
          path = Path.join(modules_dir(), file)
          data = path |> File.read!() |> :erlang.binary_to_term()
          module = data[:module]
          {module, data}
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Clears outdated module files.

  Removes files for modules that no longer use LiveStyle.
  """
  @spec cleanup_outdated(MapSet.t(module())) :: :ok
  def cleanup_outdated(active_modules) do
    case File.ls(modules_dir()) do
      {:ok, files} ->
        for file <- files, String.ends_with?(file, ".etf") do
          path = Path.join(modules_dir(), file)

          with {:ok, binary} <- File.read(path),
               data <- :erlang.binary_to_term(binary),
               module when is_atom(module) <- data[:module] do
            unless MapSet.member?(active_modules, module) do
              File.rm(path)
            end
          end
        end

      {:error, _} ->
        :ok
    end

    :ok
  end

  @doc """
  Returns the modules directory path.
  """
  @spec modules_dir() :: String.t()
  def modules_dir do
    build_path = Mix.Project.build_path()
    app = Mix.Project.config()[:app] || :live_style

    Path.join([build_path, "live_style", to_string(app), "modules"])
  end

  defp module_path(module) do
    # Use a hash of the module name to avoid filesystem issues with long names
    hash = :crypto.hash(:md5, inspect(module)) |> Base.encode16(case: :lower)
    Path.join(modules_dir(), "#{hash}.etf")
  end
end
