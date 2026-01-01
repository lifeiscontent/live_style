defmodule LiveStyle.Dev.List do
  @moduledoc false

  alias LiveStyle.Dev.Ensure

  @spec list(module(), :all | :static | :dynamic) :: [atom()]
  def list(module, filter \\ :all) when is_atom(module) do
    Ensure.ensure_live_style_module!(module)

    class_strings = module.__live_style__(:class_strings)
    dynamic_names = module.__live_style__(:dynamic_names)
    static_names = Keyword.keys(class_strings)

    case filter do
      :all -> Enum.sort(static_names ++ dynamic_names)
      :static -> Enum.sort(static_names)
      :dynamic -> Enum.sort(dynamic_names)
    end
  end
end
