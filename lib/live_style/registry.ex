defmodule LiveStyle.Registry do
  @moduledoc """
  Shared fetch/define pattern for LiveStyle registries.

  This module provides a macro that generates the common `fetch/1`, `fetch!/1`,
  and `ref/1` functions used across LiveStyle's definition modules.

  ## Usage

      defmodule LiveStyle.Vars do
        use LiveStyle.Registry,
          entity_name: "CSS variable",
          manifest_type: :var,
          ref_field: :ident

        # Module-specific code...
      end

  ## Generated Functions

  - `fetch/1` - Returns `{:ok, entry}` or `{:error, reason}`
  - `fetch!/1` - Returns entry or raises
  - `ref/1` - Extracts the ref_field from the entry
  - `store_entry/2` - Helper to store entries in manifest (private)
  """

  defmacro __using__(opts) do
    entity_name = Keyword.fetch!(opts, :entity_name)
    manifest_type = Keyword.fetch!(opts, :manifest_type)
    ref_field = Keyword.fetch!(opts, :ref_field)

    # Build the getter/putter function names dynamically
    getter = :"get_#{manifest_type}"
    putter = :"put_#{manifest_type}"

    quote do
      alias LiveStyle.Manifest

      @doc false
      @spec fetch(atom() | {module(), atom()}) :: {:ok, term()} | {:error, String.t()}
      def fetch(name) when is_atom(name), do: fetch({__MODULE__, name})

      def fetch({module, name}) do
        key = Manifest.key(module, name)
        manifest = LiveStyle.Storage.read()

        case Manifest.unquote(getter)(manifest, key) do
          nil ->
            {:error,
             "#{unquote(entity_name)} not found: #{inspect({module, name})}. " <>
               "Make sure #{inspect(module)} is compiled before this module."}

          entry ->
            {:ok, entry}
        end
      end

      @doc """
      Fetches a #{unquote(entity_name)} by reference.

      Returns the entry. Raises if not found.
      """
      @spec fetch!(atom() | {module(), atom()}) :: term()
      def fetch!(name) when is_atom(name), do: fetch!({__MODULE__, name})

      def fetch!({module, name}) do
        case fetch({module, name}) do
          {:ok, entry} -> entry
          {:error, reason} -> raise ArgumentError, reason
        end
      end

      @doc """
      Gets the #{unquote(entity_name)} reference value.
      """
      @spec ref(atom() | {module(), atom()}) :: term()
      def ref(name) when is_atom(name), do: ref({__MODULE__, name})

      def ref({module, name}) do
        entry = fetch!({module, name})
        Keyword.fetch!(entry, unquote(ref_field))
      end

      @doc false
      defp store_entry(key, entry) do
        LiveStyle.Storage.update(fn manifest ->
          case Manifest.unquote(getter)(manifest, key) do
            ^entry -> manifest
            _ -> Manifest.unquote(putter)(manifest, key, entry)
          end
        end)
      end

      # Allow modules to override generated functions
      defoverridable fetch: 1, fetch!: 1, ref: 1
    end
  end
end
