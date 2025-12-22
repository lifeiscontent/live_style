defmodule LiveStyle.LookupError do
  @moduledoc false

  @spec keyframes(atom()) :: String.t()
  def keyframes(name) do
    """
    Unknown keyframes: #{name}

    Make sure css_keyframes(:#{name}, ...) is defined before it's referenced.
    If referencing from another module, ensure that module is compiled first.
    """
  end

  @spec view_transition(module(), atom()) :: String.t()
  def view_transition(module, name) do
    """
    Unknown view_transition: #{inspect(module)}.#{name}

    Make sure css_view_transition(:#{name}, ...) is defined before it's referenced.
    """
  end

  @spec position_try(module(), atom()) :: String.t()
  def position_try(module, name) do
    """
    Unknown position_try: #{inspect(module)}.#{name}

    Make sure css_position_try(:#{name}, ...) is defined before it's referenced.
    """
  end

  @spec theme(module(), atom(), atom()) :: String.t()
  def theme(module, namespace, theme_name) do
    """
    Unknown theme: #{inspect(module)}.#{namespace}.#{theme_name}

    Make sure css_theme(:#{namespace}, :#{theme_name}, ...) is defined before it's referenced.
    """
  end

  @spec var(module(), atom(), atom()) :: String.t()
  def var(module, namespace, name) do
    """
    Unknown CSS variable: #{inspect(module)}.#{namespace}.#{name}

    Make sure #{inspect(module)} is compiled before this module.
    """
  end
end
