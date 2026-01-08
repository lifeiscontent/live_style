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

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(path, content) do
      {:ok, :written}
    end
  end
end
