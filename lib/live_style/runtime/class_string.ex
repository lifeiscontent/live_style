defmodule LiveStyle.Runtime.ClassString do
  @moduledoc false

  alias LiveStyle.Runtime.Attrs

  @spec resolve_class_string(module(), list()) :: String.t()
  def resolve_class_string(module, refs) when is_atom(module) and is_list(refs) do
    %LiveStyle.Attrs{class: class} = Attrs.resolve_attrs(module, refs, nil)
    class
  end
end
