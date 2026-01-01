defmodule LiveStyle.Compiler.CSS.Writer do
  @moduledoc """
  File writing operations for LiveStyle CSS output.

  This module handles writing CSS content to files with change detection
  to avoid unnecessary writes.

  ## Responsibilities

  - Writing CSS content to files
  - Change detection (skip write if content unchanged)
  - Directory creation

  For CSS generation, see `LiveStyle.Compiler.CSS.Pipeline`.
  """

  alias LiveStyle.Compiler.CSS.Pipeline
  alias LiveStyle.Compiler.CSS.Writer.File, as: WriterFile

  @doc """
  Writes CSS to a file if it has changed.

  Generates CSS from the current manifest and writes it to the specified path.

  ## Options

    * `:stats` - Include a stats comment at the top of the file (default: true)

  ## Returns

    * `{:ok, :written}` - File was written (content changed or file didn't exist)
    * `{:ok, :unchanged}` - File exists with identical content, no write performed
    * `{:error, reason}` - An error occurred during write

  ## Example

      LiveStyle.Compiler.CSS.Writer.write("priv/static/live.css")
      LiveStyle.Compiler.CSS.Writer.write("priv/static/live.css", stats: false)
  """
  @spec write(String.t(), keyword()) :: {:ok, :written | :unchanged} | {:error, term()}
  def write(path, opts \\ []) do
    css = Pipeline.generate(opts)
    write_content(path, css)
  end

  @doc """
  Writes CSS content directly to a file.

  Use this when you already have the CSS content and don't need generation.

  ## Returns

    * `{:ok, :written}` - File was written
    * `{:ok, :unchanged}` - File exists with identical content
    * `{:error, reason}` - An error occurred
  """
  @spec write_content(String.t(), String.t()) ::
          {:ok, :written | :unchanged} | {:error, term()}
  def write_content(path, css) do
    WriterFile.write_if_changed(path, css)
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
  defdelegate write_if_changed(path, content), to: WriterFile
end
