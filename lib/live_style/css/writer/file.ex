defmodule LiveStyle.CSS.Writer.File do
  @moduledoc false

  @spec write_if_changed(String.t(), String.t()) ::
          {:ok, :written | :unchanged} | {:error, term()}
  def write_if_changed(path, content) do
    case File.read(path) do
      {:ok, existing} when existing == content ->
        {:ok, :unchanged}

      _ ->
        dir = Path.dirname(path)

        with :ok <- File.mkdir_p(dir),
             :ok <- File.write(path, content) do
          {:ok, :written}
        end
    end
  end
end
