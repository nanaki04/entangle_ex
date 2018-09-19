defmodule Entangle.Seed do
  @moduledoc """
  Use the `Entangle.Seed` module to define re-usable settings for your function compositions.

  ## Examples

      iex> defmodule Mod.Composition.Log do
      ...>   use Entangle.Thorn, layers: [:test]
      ...>
      ...>   @impl Entangle.Thorn
      ...>   def run(next) do
      ...>     fn state ->
      ...>       state
      ...>       |> IO.inspect(label: "state before")
      ...>       |> next.()
      ...>       |> IO.inspect(label: "state after")
      ...>     end
      ...>   end
      ...> end
      ...>
      ...> defmodule Mod.Composition.Settings do
      ...>   use Entangle.Seed
      ...>
      ...>   layers [:dev, :test, :prod]
      ...>   active_layers [Mix.env()]
      ...>   thorn Mod.Composition.Log
      ...>   root Mod.Composition.Log
      ...> end
      ...>
      ...> defmodule Mod.Composition.AddTest do
      ...>   use Entangle.Branch, layers: [:test]
      ...>
      ...>   @impl Entangle.Branch
      ...>   def run(state), do: {:ok, state + 1}
      ...> end
      ...>
      ...> defmodule Mod.Composition.Add do
      ...>   use Entangle.Branch, layers: [:dev, :prod]
      ...>
      ...>   @impl Entangle.Branch
      ...>   def run(state), do: {:ok, state + 1}
      ...> end
      ...>
      ...> defmodule Mod.Composition.Compositions do
      ...>   use Entangle.Entangler, seed: Mod.Composition.Settings
      ...>
      ...>   entangle :add2, [
      ...>     Mod.Composition.AddTest,
      ...>     Mod.Composition.Add,
      ...>     Mod.Composition.AddTest
      ...>   ]
      ...> end
      ...>
      ...> Mod.Composition.Compositions.add2(1)
      {:ok, 3}

  """

  defstruct layers: [],
            layer_mask: 0,
            thorns: [],
            roots: []

  @typedoc """
  A map of settings, including layer setting and middleware.
  The `thorns` middleware will be called inbetween every function,
  while the `roots` middleware we be called on the composition as a whole.
  """
  @type t :: %Entangle.Seed{
          layers: Layers.t(),
          layer_mask: Layers.Mask.t(),
          thorns: [Entangle.Thorn.t()],
          roots: [Entangle.Thorn.t()]
        }

  @doc """
  Callback function to obtain the setting defined at compile time.
  This callback will be automatically defined upon calling use `Entangle.Seed`.
  """
  @callback settings() :: t

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Entangle.Seed, only: :macros
      import Entangle.Thorn, only: :functions
      @behaviour Entangle.Seed

      Module.register_attribute(__MODULE__, :thorns, accumulate: true)
      Module.register_attribute(__MODULE__, :roots, accumulate: true)
      Module.register_attribute(__MODULE__, :layers, accumulate: true)
      Module.register_attribute(__MODULE__, :active_layers, accumulate: true)
      Module.register_attribute(__MODULE__, :layer_mask, [])

      @before_compile Entangle.Seed
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    layers = Module.get_attribute(env.module, :layers)
    active_layers = Module.get_attribute(env.module, :active_layers)
    layer_mask = Entangle.Filter.make_layer_mask(layers, active_layers)

    thorns =
      Module.get_attribute(env.module, :thorns)
      |> Enum.filter(fn thorn -> Entangle.Filter.layer_enabled?(thorn, layer_mask, layers) end)

    roots =
      Module.get_attribute(env.module, :roots)
      |> Enum.filter(fn root -> Entangle.Filter.layer_enabled?(root, layer_mask, layers) end)

    quote do
      @impl Entangle.Seed
      def settings() do
        %Entangle.Seed{
          layers: unquote(layers),
          layer_mask: unquote(layer_mask),
          thorns: unquote(thorns),
          roots: unquote(roots)
        }
      end
    end
  end

  @doc """
  Obtains the default settings.
  The default settings contain no layer settings,
  and will have no middleware setup.
  """
  @spec default_settings() :: t
  def default_settings() do
    %Entangle.Seed{}
  end

  @doc """
  Define a layer in the form of an atom.

  ## Examples

      iex> defmodule Mod.Composure.TestLayer do
      ...>   use Entangle.Seed
      ...>
      ...>   layer :test
      ...>   layer :dev
      ...>   layer :prod
      ...> end
      ...> Mod.Composure.TestLayer.settings()
      %Entangle.Seed{layers: [:prod, :dev, :test]}

  """
  defmacro layer(layer) do
    quote do
      @layers unquote(layer)
    end
  end

  @doc """
  Define multiple layers at once in the form of a list of atoms.

  ## Examples

      iex> defmodule Mod.Composure.TestLayers do
      ...>   use Entangle.Seed
      ...>
      ...>   layers [
      ...>     :test,
      ...>     :dev,
      ...>     :prod
      ...>   ]
      ...>
      ...> end
      ...> Mod.Composure.TestLayers.settings()
      %Entangle.Seed{layers: [:prod, :dev, :test]}

  """
  defmacro layers(layers) do
    quote do
      Enum.each(unquote(layers), fn layer ->
        @layers layer
      end)
    end
  end

  @doc """
  Flag a layer as enabled.
  This will be generally based on environment settings.
  Expects an atom, that was previously defined using the `layer` or `layers` macro.

  ## Examples

      iex> defmodule Mod.Composure.TestActiveLayer do
      ...>   use Entangle.Seed
      ...>
      ...>   layers [
      ...>     :test,
      ...>     :dev,
      ...>     :prod
      ...>   ]
      ...>
      ...>   active_layer Mix.env()
      ...>
      ...> end
      ...> Mod.Composure.TestActiveLayer.settings()
      %Entangle.Seed{layer_mask: Integer.undigits([1, 0, 0], 2), layers: [:prod, :dev, :test]}

  """
  defmacro active_layer(layer) do
    quote do
      @active_layers unquote(layer)
    end
  end

  @doc """
  Flags multiple layers as enabled at once.
  Expects a list of atoms, that are previously defined using the `layer` or `layers` macro.
  """
  defmacro active_layers(layers) do
    quote do
      Enum.each(unquote(layers), fn layer ->
        @active_layers layer
      end)
    end
  end

  @doc """
  Register middleware to be run inbetween every branch or function call that makes up a composition.

  ## Examples

      iex> defmodule Mod.Composition.ThornLog do
      ...>   use Entangle.Thorn, layers: [:*]
      ...>
      ...>   @impl Entangle.Thorn
      ...>   def run(next) do
      ...>     fn state ->
      ...>       state
      ...>       |> IO.inspect(label: "state before")
      ...>       |> next.()
      ...>       |> IO.inspect(label: "state after")
      ...>     end
      ...>   end
      ...> end
      ...>
      ...> defmodule Mod.Composition.ThornSettings do
      ...>   use Entangle.Seed
      ...>
      ...>   thorn Mod.Composition.ThornLog
      ...> end
      ...>
      ...> Mod.Composition.ThornSettings.settings()
      %Entangle.Seed{thorns: [SeedTest.Mod.Composition.ThornLog]}

  """
  defmacro thorn(thorn) do
    quote do
      @thorns unquote(thorn)
    end
  end

  @doc """
  Register multiple middlewares to be run inbetween every branch or function call that makes up a composition, at once.
  """
  defmacro thorns(thorns) do
    quote do
      Enum.each(unquote(thorns), fn thorn ->
        @thorns thorn
      end)
    end
  end

  @doc """
  Register middleware to be run around every composition.

  ## Examples

      iex> defmodule Mod.Composition.RootLog do
      ...>   use Entangle.Thorn, layers: [:*]
      ...>
      ...>   @impl Entangle.Thorn
      ...>   def run(next) do
      ...>     fn state ->
      ...>       state
      ...>       |> IO.inspect(label: "state before")
      ...>       |> next.()
      ...>       |> IO.inspect(label: "state after")
      ...>     end
      ...>   end
      ...> end
      ...>
      ...> defmodule Mod.Composition.RootSettings do
      ...>   use Entangle.Seed
      ...>
      ...>   root Mod.Composition.RootLog
      ...> end
      ...>
      ...> Mod.Composition.RootSettings.settings()
      %Entangle.Seed{roots: [SeedTest.Mod.Composition.RootLog]}

  """
  defmacro root(root) do
    quote do
      @roots unquote(root)
    end
  end

  @doc """
  Register multiple middlewares to be run around every composition at once.
  """
  defmacro roots(roots) do
    quote do
      Enum.each(unquote(roots), fn root ->
        @roots root
      end)
    end
  end
end
