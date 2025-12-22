defmodule LiveStyle.Dev.ClassInfo do
  @moduledoc false

  alias LiveStyle.Dev.Ensure
  alias LiveStyle.Dev.Properties

  @spec class_info(module(), atom()) :: map() | {:error, :not_found}
  def class_info(module, class_name) when is_atom(module) and is_atom(class_name) do
    Ensure.ensure_live_style_module!(module)

    case LiveStyle.get_metadata(module, {:class, class_name}) do
      nil ->
        {:error, :not_found}

      metadata ->
        class_string = LiveStyle.get_css_class(module, class_name)
        properties = Properties.extract_properties(metadata)
        css = Properties.build_css_string(properties)

        %{
          name: class_name,
          class: class_string,
          css: css,
          properties: properties,
          dynamic?: match?({:__dynamic__, _, _, _}, metadata[:declaration])
        }
    end
  end
end
