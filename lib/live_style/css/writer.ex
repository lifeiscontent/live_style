defmodule LiveStyle.CSS.Writer do
  @moduledoc """
  File writing operations for LiveStyle CSS output.

  This module handles writing generated CSS to files.
  """

  alias LiveStyle.CSS
  alias LiveStyle.CSS.Writer.{File, Stats}

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

    css =
      if Keyword.get(opts, :stats, true) do
        Stats.comment(manifest) <> "\n\n" <> css
      else
        css
      end

    File.write_if_changed(path, css)
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
  defdelegate write_if_changed(path, content), to: File
end
