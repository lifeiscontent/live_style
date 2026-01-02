defmodule LiveStyle.Storage.Adapter do
  @moduledoc """
  Behaviour for LiveStyle storage adapters.

  This allows swapping storage implementations for testing or alternative backends.

  ## Implementing an Adapter

      defmodule MyAppWeb.InMemoryStorage do
        @behaviour LiveStyle.Storage.Adapter

        @impl true
        def read, do: Agent.get(__MODULE__, & &1)

        @impl true
        def write(manifest), do: Agent.update(__MODULE__, fn _ -> manifest end)

        @impl true
        def update(fun) do
          Agent.update(__MODULE__, fn manifest ->
            fun.(manifest)
          end)
        end

        @impl true
        def clear, do: Agent.update(__MODULE__, fn _ -> LiveStyle.Manifest.empty() end)
      end

  ## Configuration

      config :live_style, storage_adapter: MyAppWeb.InMemoryStorage
  """

  alias LiveStyle.Manifest

  @doc """
  Reads the manifest from storage.

  Returns an empty manifest if storage is empty or uninitialized.
  """
  @callback read() :: Manifest.t()

  @doc """
  Writes the manifest to storage.
  """
  @callback write(Manifest.t()) :: :ok

  @doc """
  Atomically updates the manifest.

  The update function receives the current manifest and returns the new manifest.
  If the returned manifest is identical (same reference), the write may be skipped.
  """
  @callback update((Manifest.t() -> Manifest.t())) :: :ok

  @doc """
  Clears the manifest, resetting to empty state.
  """
  @callback clear() :: :ok
end
