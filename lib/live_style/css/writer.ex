defmodule LiveStyle.CSS.Writer do
  @moduledoc """
  File writing operations for LiveStyle CSS output.

  This module handles writing generated CSS to files, including:
  - Content comparison to avoid unnecessary writes
  - Directory creation
  - Optional stats comments

  ## Example

      LiveStyle.CSS.Writer.write("priv/static/live.css")
      # => {:ok, :written} or {:ok, :unchanged}
  """

  alias LiveStyle.CSS

  @doc """
  Writes CSS to a file if it has changed.

  ## Options

    * `:stats` - Include a stats comment at the top of the file (default: true)

  ## Returns

    * `{:ok, :written}` - File was written (content changed or file didn't exist)
    * `{:ok, :unchanged}` - File exists with identical content, no write performed
    * `{:error, reason}` - An error occurred during write

  ## Example

      LiveStyle.CSS.Writer.write("priv/static/live.css")
      LiveStyle.CSS.Writer.write("priv/static/live.css", stats: false)
  """
  @spec write(String.t(), keyword()) :: {:ok, :written | :unchanged} | {:error, term()}
  def write(path, opts \\ []) do
    manifest = LiveStyle.Storage.read()
    css = CSS.generate(manifest)

    # Add stats comment if requested
    css =
      if Keyword.get(opts, :stats, true) do
        stats = collect_stats(manifest)
        "/* LiveStyle: #{stats} */\n\n#{css}"
      else
        css
      end

    write_if_changed(path, css)
  end

  @doc """
  Writes content to a file only if it differs from existing content.

  Creates parent directories if they don't exist.

  ## Returns

    * `{:ok, :written}` - File was written
    * `{:ok, :unchanged}` - File exists with identical content
    * `{:error, reason}` - An error occurred
  """
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

  # Collects statistics about the manifest for the stats comment
  defp collect_stats(manifest) do
    vars_count = map_size(manifest.vars)
    keyframes_count = map_size(manifest.keyframes)
    classes_count = map_size(manifest.classes)
    themes_count = map_size(manifest.themes)

    "#{vars_count} vars, #{keyframes_count} keyframes, #{classes_count} classes, #{themes_count} themes"
  end
end
