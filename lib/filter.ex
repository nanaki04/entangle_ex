defmodule Entangle.Filter do
  @moduledoc false
  # This module is used internally.

  @doc false
  @spec make_layer_mask([atom], [atom]) :: Layers.Mask.t()
  def make_layer_mask(layers, active_layers) do
    Enum.reduce(active_layers, Layers.Mask.new(), fn layer, mask ->
      Layers.enable!(layers, mask, layer)
    end)
  end

  @doc false
  @spec layer_enabled?(Entangle.Branch.t() | Entangle.Thorn.t(), Layers.Mask.t(), [atom]) ::
          boolean
  def layer_enabled?({_, opts}, layer_mask, layers) do
    case Keyword.get(opts, :layers, [:*]) do
      nil -> true
      [:*] -> true
      attached_layers -> Layers.enabled?(layers, layer_mask, attached_layers)
    end
  end

  def layer_enabled?(module, layer_mask, layers) do
    case module.layers() do
      nil -> true
      [:*] -> true
      attached_layers -> Layers.enabled?(layers, layer_mask, attached_layers)
    end
  end
end
