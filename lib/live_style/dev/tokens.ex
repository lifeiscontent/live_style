defmodule LiveStyle.Dev.Tokens do
  @moduledoc false

  @spec tokens(module()) :: map()
  def tokens(module) when is_atom(module) do
    manifest = LiveStyle.Storage.read()

    vars = extract_tokens_by_type(manifest, module, :var)
    consts = extract_tokens_by_type(manifest, module, :const)
    keyframes = extract_tokens_by_type(manifest, module, :keyframes)
    themes = extract_tokens_by_type(manifest, module, :theme)

    %{
      vars: vars,
      consts: consts,
      keyframes: keyframes,
      themes: themes
    }
  end

  defp extract_tokens_by_type(manifest, module, type) do
    module_prefix = inspect(module)

    manifest_key =
      case type do
        :var -> :vars
        :const -> :consts
        :keyframes -> :keyframes
        :theme -> :themes
      end

    (manifest[manifest_key] || %{})
    |> Enum.filter(fn {key, _data} -> String.starts_with?(key, module_prefix) end)
    |> Enum.map(fn {key, _data} -> parse_token_key(key, module_prefix) end)
    |> Enum.reject(&is_nil/1)
    |> group_tokens(type)
  end

  defp parse_token_key(key, module_prefix) do
    rest = String.replace_prefix(key, module_prefix <> ".", "")

    case String.split(rest, ".") do
      [namespace, name] -> {String.to_atom(namespace), String.to_atom(name)}
      [name] -> String.to_atom(name)
      _ -> nil
    end
  end

  defp group_tokens(tokens, type) when type in [:var, :const] do
    tokens
    |> Enum.group_by(
      fn
        {namespace, _name} -> namespace
        _name -> :default
      end,
      fn
        {_namespace, name} -> name
        name -> name
      end
    )
  end

  defp group_tokens(tokens, _type), do: tokens
end
