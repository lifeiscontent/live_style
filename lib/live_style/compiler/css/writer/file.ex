defmodule LiveStyle.Compiler.CSS.Writer.File do
  @moduledoc false

  @spec write_if_changed(String.t(), String.t()) ::
          {:ok, :written | :unchanged} | {:error, term()}
  def write_if_changed(path, content) do
    case File.read(path) do
      {:ok, existing} when existing == content ->
        {:ok, :unchanged}

      {:ok, _different} ->
        # Content changed, write new file
        write_file(path, content)

      {:error, :enoent} ->
        # File doesn't exist yet, create it
        write_file(path, content)

      {:error, reason} ->
        # Actual read error (permissions, etc.) - propagate it
        {:error, {:read_error, reason}}
    end
  end

  defp write_file(path, content) do
    dir = Path.dirname(path)
    temp_path = Path.join(dir, ".#{Path.basename(path)}.tmp")

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(temp_path, content) do
      case File.rename(temp_path, path) do
        :ok ->
          {:ok, :written}

        {:error, reason} ->
          File.rm(temp_path)
          {:error, reason}
      end
    else
      {:error, reason} ->
        File.rm(temp_path)
        {:error, reason}
    end
  end
end
