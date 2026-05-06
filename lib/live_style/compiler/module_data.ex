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

    temp_path = path <> ".tmp"

    try do
      File.write!(temp_path, :erlang.term_to_binary(data))
      File.rename!(temp_path, path)
    rescue
      error ->
        File.rm(temp_path)
        reraise error, __STACKTRACE__
    end

    :ok
  end

  @doc """
  Returns a cheap fingerprint for a source file.

  The fingerprint lets stale cleanup skip source parsing when the source has not
  changed since the LiveStyle module data was written.
  """
  @spec source_fingerprint(String.t() | nil) :: {term(), non_neg_integer()} | nil
  def source_fingerprint(source) when is_binary(source) do
    case File.stat(source) do
      {:ok, %{mtime: mtime, size: size}} -> {mtime, size}
      {:error, _reason} -> nil
    end
  end

  def source_fingerprint(_source), do: nil

  @doc """
  Reads module data from a per-module file.

  Returns `nil` if the file doesn't exist.
  """
  @spec read(module()) :: map() | nil
  def read(module) when is_atom(module) do
    path = module_path(module)

    if File.exists?(path) do
      case File.read(path) do
        {:ok, binary} ->
          :erlang.binary_to_term(binary)

        {:error, _} ->
          nil
      end
    else
      nil
    end
  catch
    :error, :badarg -> nil
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
        |> Enum.flat_map(fn file ->
          path = Path.join(modules_dir(), file)
          read_module_file(path)
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

          try do
            with {:ok, binary} <- File.read(path),
                 data <- :erlang.binary_to_term(binary),
                 module when is_atom(module) <- data[:module] do
              unless MapSet.member?(active_modules, module) do
                File.rm(path)
              end
            end
          catch
            :error, :badarg -> File.rm(path)
          end
        end

      {:error, _} ->
        :ok
    end

    :ok
  end

  @doc """
  Removes stale per-module files before manifest merge.

  A file is stale when its source file was deleted, or when the source no longer
  matches the source fingerprint recorded during compilation and the fallback
  loaded-module/source checks show the module no longer uses LiveStyle. This
  keeps incremental compiles from preserving CSS for modules that were deleted
  or migrated away from LiveStyle.
  """
  @spec cleanup_stale() :: :ok
  def cleanup_stale do
    case File.ls(modules_dir()) do
      {:ok, files} ->
        for file <- files, String.ends_with?(file, ".etf") do
          path = Path.join(modules_dir(), file)
          cleanup_stale_module_file(path)
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

  defp read_module_file(path) do
    case File.read(path) do
      {:ok, binary} ->
        try do
          data = :erlang.binary_to_term(binary)
          module = data[:module]
          if is_atom(module), do: [{module, data}], else: []
        catch
          :error, :badarg -> []
        end

      {:error, _} ->
        []
    end
  end

  defp cleanup_stale_module_file(path) do
    case read_module_file(path) do
      [{module, data}] ->
        if stale_module_data?(module, data), do: File.rm(path)

      [] ->
        File.rm(path)
    end
  end

  defp stale_module_data?(module, data) do
    source = data[:source]

    cond do
      is_binary(source) and not File.exists?(source) ->
        true

      source_unchanged?(source, data[:source_fingerprint]) ->
        false

      Code.ensure_loaded?(module) ->
        not function_exported?(module, :__live_style__, 1)

      is_binary(source) ->
        not source_declares_live_style_module?(source, module)

      true ->
        false
    end
  end

  defp source_unchanged?(source, fingerprint)
       when is_binary(source) and not is_nil(fingerprint) do
    source_fingerprint(source) == fingerprint
  end

  defp source_unchanged?(_source, _fingerprint), do: false

  defp source_declares_live_style_module?(source, module) do
    with {:ok, contents} <- File.read(source),
         {:ok, ast} <- Code.string_to_quoted(contents) do
      live_style_module_in_ast?(ast, module, nil)
    else
      _ -> true
    end
  end

  defp live_style_module_in_ast?({:defmodule, _meta, [module_ast, [do: body]]}, target, parent) do
    module = expand_module_ast(module_ast, parent)

    (module == target and body_uses_live_style?(body)) or
      live_style_module_in_ast?(body, target, module)
  end

  defp live_style_module_in_ast?({left, right}, target, parent) do
    live_style_module_in_ast?(left, target, parent) or
      live_style_module_in_ast?(right, target, parent)
  end

  defp live_style_module_in_ast?(tuple, target, parent) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> live_style_module_in_ast?(target, parent)
  end

  defp live_style_module_in_ast?(list, target, parent) when is_list(list) do
    Enum.any?(list, &live_style_module_in_ast?(&1, target, parent))
  end

  defp live_style_module_in_ast?(_ast, _target, _parent), do: false

  defp expand_module_ast({:__aliases__, _meta, parts}, nil), do: Module.concat(parts)

  defp expand_module_ast({:__aliases__, _meta, [part]}, parent) when not is_nil(parent),
    do: Module.concat(parent, part)

  defp expand_module_ast({:__aliases__, _meta, parts}, _parent), do: Module.concat(parts)

  defp expand_module_ast(module, _parent) when is_atom(module), do: module

  defp body_uses_live_style?({:defmodule, _meta, _args}), do: false
  defp body_uses_live_style?({:use, _meta, [module_ast | _]}), do: live_style_alias?(module_ast)

  defp body_uses_live_style?({left, right}) do
    body_uses_live_style?(left) or body_uses_live_style?(right)
  end

  defp body_uses_live_style?(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> body_uses_live_style?()
  end

  defp body_uses_live_style?(list) when is_list(list) do
    Enum.any?(list, &body_uses_live_style?/1)
  end

  defp body_uses_live_style?(_), do: false

  defp live_style_alias?({:__aliases__, _meta, [:LiveStyle]}), do: true
  defp live_style_alias?(LiveStyle), do: true
  defp live_style_alias?(_), do: false

  defp module_path(module) do
    # Use a hash of the module name to avoid filesystem issues with long names
    hash = :crypto.hash(:md5, inspect(module)) |> Base.encode16(case: :lower)
    Path.join(modules_dir(), "#{hash}.etf")
  end

  # ===========================================================================
  # Per-Module Usage Tracking (for tree-shaking)
  # ===========================================================================

  @doc """
  Returns the usage directory path.
  """
  @spec usage_dir() :: String.t()
  def usage_dir do
    build_path = Mix.Project.build_path()
    app = Mix.Project.config()[:app] || :live_style

    Path.join([build_path, "live_style", to_string(app), "usage"])
  end

  @doc """
  Records class usage for a consuming module.

  Used as a fallback for usage recorded outside a compiling LiveStyle module.
  During normal compilation, LiveStyle's before-compile hook writes all usage
  for the module in one batch.
  """
  @spec record_usage(module(), module(), atom()) :: :ok
  def record_usage(consuming_module, defining_module, class_name)
      when is_atom(consuming_module) and is_atom(defining_module) and is_atom(class_name) do
    # Read existing usage, add new entry, write back atomically
    path = usage_path(consuming_module)
    usage = read_usage_file(path)
    updated = MapSet.put(usage, {defining_module, class_name})
    write_usage(consuming_module, updated)
  end

  @doc """
  Writes all usage for a consuming module in one atomic operation.
  """
  @spec write_usage(module(), MapSet.t({module(), atom()})) :: :ok
  def write_usage(consuming_module, usage)
      when is_atom(consuming_module) and is_struct(usage, MapSet) do
    path = usage_path(consuming_module)
    dir = Path.dirname(path)
    File.mkdir_p!(dir)

    write_atomic(path, :erlang.term_to_binary(%{module: consuming_module, usage: usage}))
    :ok
  end

  # Atomic write: write to temp file then rename
  defp write_atomic(path, binary) do
    tmp_path = path <> ".tmp"
    File.write!(tmp_path, binary)
    File.rename!(tmp_path, path)
  end

  defp usage_path(module) do
    hash = :crypto.hash(:md5, inspect(module)) |> Base.encode16(case: :lower)
    Path.join(usage_dir(), "#{hash}.etf")
  end

  defp read_usage_file(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, binary} ->
          binary
          |> decode_usage_data()
          |> usage_from_data()

        {:error, _} ->
          MapSet.new()
      end
    else
      MapSet.new()
    end
  end

  defp read_usage_owner(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, binary} ->
          binary
          |> decode_usage_data()
          |> usage_owner_from_data()

        {:error, _} ->
          nil
      end
    end
  end

  defp decode_usage_data(binary) do
    :erlang.binary_to_term(binary)
  rescue
    ArgumentError -> MapSet.new()
  end

  defp usage_from_data(%{usage: %MapSet{} = usage}), do: usage
  defp usage_from_data(%MapSet{} = usage), do: usage
  defp usage_from_data(_), do: MapSet.new()

  defp usage_owner_from_data(%{module: module}) when is_atom(module), do: module
  defp usage_owner_from_data(_), do: nil

  @doc """
  Collects all usage from per-module usage files.

  Called after compilation to merge all usage into a single manifest.
  """
  @spec collect_all_usage() :: MapSet.t()
  def collect_all_usage do
    usage_dir()
    |> File.ls()
    |> case do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".etf"))
        |> Enum.reduce(MapSet.new(), fn file, acc ->
          path = Path.join(usage_dir(), file)
          usage = read_usage_file(path)
          MapSet.union(acc, usage)
        end)

      {:error, _} ->
        MapSet.new()
    end
  end

  @doc """
  Removes per-module usage files for consumers that are no longer active.
  """
  @spec cleanup_stale_usage(MapSet.t(module())) :: :ok
  def cleanup_stale_usage(active_modules) do
    with {:ok, files} <- File.ls(usage_dir()) do
      files
      |> Enum.filter(&String.ends_with?(&1, ".etf"))
      |> Enum.each(&cleanup_stale_usage_file(&1, active_modules))
    end

    :ok
  end

  defp cleanup_stale_usage_file(file, active_modules) do
    path = Path.join(usage_dir(), file)

    case read_usage_owner(path) do
      nil -> :ok
      module -> remove_stale_usage_file(path, module, active_modules)
    end
  end

  defp remove_stale_usage_file(path, module, active_modules) do
    unless MapSet.member?(active_modules, module), do: File.rm(path)
  end

  @doc """
  Clears all usage files.

  Called during `mix compile.live_style --clean` to remove stale usage data.
  """
  @spec clear_usage() :: :ok
  def clear_usage do
    File.rm_rf(usage_dir())
    :ok
  end
end
