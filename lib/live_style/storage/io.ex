defmodule LiveStyle.Storage.IO do
  @moduledoc false

  alias LiveStyle.Manifest

  @spec read(String.t()) :: Manifest.t()
  def read(file_path) do
    if File.exists?(file_path) do
      read_file(file_path)
    else
      Manifest.empty()
    end
  end

  @spec write(Manifest.t(), String.t()) :: :ok
  def write(manifest, file_path) do
    File.write!(file_path, :erlang.term_to_binary(manifest))
    :ok
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, binary} ->
        parse_manifest(binary, file_path)

      {:error, reason} ->
        require Logger
        Logger.warning("LiveStyle: Failed to read manifest at #{file_path}: #{inspect(reason)}")
        Manifest.empty()
    end
  end

  defp parse_manifest(binary, file_path) do
    manifest = :erlang.binary_to_term(binary)
    Manifest.ensure_keys(manifest)
  catch
    :error, :badarg ->
      require Logger
      Logger.warning("LiveStyle: Corrupt manifest at #{file_path}, starting fresh")
      Manifest.empty()
  end
end
