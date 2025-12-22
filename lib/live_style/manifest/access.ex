defmodule LiveStyle.Manifest.Access do
  @moduledoc false

  alias LiveStyle.{LookupError, Manifest, Storage}

  @spec theme!(module(), atom(), atom()) :: map()
  def theme!(module, namespace, theme_name) do
    key = Manifest.namespaced_key(module, namespace, theme_name)
    manifest = Storage.read()

    case Manifest.get_theme(manifest, key) do
      nil -> raise ArgumentError, LookupError.theme(module, namespace, theme_name)
      entry -> entry
    end
  end

  @spec keyframes!(module(), atom()) :: map()
  def keyframes!(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = Storage.read()

    case Manifest.get_keyframes(manifest, key) do
      nil -> raise ArgumentError, LookupError.keyframes(name)
      entry -> entry
    end
  end

  @spec view_transition!(module(), atom()) :: map()
  def view_transition!(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = Storage.read()

    case Manifest.get_view_transition(manifest, key) do
      nil -> raise ArgumentError, LookupError.view_transition(module, name)
      entry -> entry
    end
  end

  @spec position_try!(module(), atom()) :: map()
  def position_try!(module, name) do
    key = Manifest.simple_key(module, name)
    manifest = Storage.read()

    case Manifest.get_position_try(manifest, key) do
      nil -> raise ArgumentError, LookupError.position_try(module, name)
      entry -> entry
    end
  end

  @spec var!(module(), atom(), atom()) :: map()
  def var!(module, namespace, name) do
    key = Manifest.namespaced_key(module, namespace, name)
    manifest = Storage.read()

    case Manifest.get_var(manifest, key) do
      nil -> raise ArgumentError, LookupError.var(module, namespace, name)
      entry -> entry
    end
  end
end
