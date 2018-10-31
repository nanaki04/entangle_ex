defmodule Entangle.Entangler do
  import ResultEx, only: [bind: 1, bind: 2]

  @moduledoc """
  Entangle is a library for composing (entangling) functions (branches).
  The composed functions and the resulting composition itself can be wrapped by middleware (thorns).
  The functions and middleware can be setup to run, or be ignored by adding them to an optional layer.
  This can be useful for enabling loggers during development, or swap certain functionality with mocks during tests.

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

  @typedoc """
  The state object to pass around the composed functions.
  The structure and type of the state object can be freely decided by the user.
  This type is merely used for clarity.
  """
  @type state :: term

  @typedoc """
  The result every branch or middleware is supposed to return.
  Return values should always be wrapped in an :ok or an :error tuple pair.
  """
  @type result :: {:ok, state} | {:error, term}

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Entangle.Entangler, only: :macros
      import Entangle.Branch, only: :functions

      settings =
        Keyword.get(opts, :settings)
        |> OptionEx.return()
        |> OptionEx.or_else(Keyword.get(opts, :seed))
        |> OptionEx.return()
        |> OptionEx.or_else(Entangle.Seed.default_settings())

      Module.register_attribute(__MODULE__, :entangles, accumulate: true)
      Module.register_attribute(__MODULE__, :settings, [])
      @settings if is_atom(settings), do: settings.settings(), else: settings

      @before_compile Entangle.Entangler
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    entangles = Module.get_attribute(env.module, :entangles)

    %Entangle.Seed{
      layers: layers,
      layer_mask: layer_mask,
      thorns: thorns,
      roots: roots
    } = Module.get_attribute(env.module, :settings)

    Enum.map(entangles, fn {function_name, branches} ->
      branches =
        Enum.filter(branches, fn branch ->
          Entangle.Filter.layer_enabled?(branch, layer_mask, layers)
        end)

      quote do
        def unquote(function_name)(state) do
          # TODO find a way to compose on compile
          Entangle.Entangler.compose_branches(
            unquote(branches),
            unquote(thorns),
            unquote(roots)
          ).(state)
        end
      end
    end)
    # TODO find a more safe way to combine the quoted expressions into one
    |> (&{:__block__, [], &1}).()
  end

  @doc """
  Builds a function composition.
  The first argument will be the function name in the form of an atom.
  The second argument will be the list of functions, either in the form of a module name of a module using the `Entangle.Branch` behaviour,
  or created on the fly by the `Engangle.Entangler.branch` function.

  ## Examples

      iex> defmodule Composure.Add3 do
      ...>   use Entangle.Entangler
      ...> 
      ...>   def add(x), do: {:ok, x + 1}
      ...> 
      ...>   entangle :add3, [
      ...>     branch(&__MODULE__.add/1),
      ...>     branch(&__MODULE__.add/1),
      ...>     branch(&__MODULE__.add/1)
      ...>   ]
      ...> 
      ...> end
      ...> 
      ...> Composure.Add3.add3(2)
      {:ok, 5}

  """
  @spec entangle(atom, [Entangle.Branch.t()]) :: Macro.t()
  defmacro entangle(function_name, branches) do
    quote do
      @entangles {unquote(function_name), unquote(branches)}
    end
  end

  @doc """
  Combines the branches into a function composition.
  This function is called during the pre compile phase, and should not be called directly.
  """
  @spec compose_branches([Entangle.Branch.t()], [Entangle.Thorn.t()], [Entangle.Thorn.t()]) ::
          (state -> result)
  def compose_branches(branches, thorns, roots) do
    composition =
      Enum.reverse(branches)
      |> Enum.reduce(&{:ok, &1}, fn
        {run, _}, acc ->
          run = compose_thorns(thorns, bind(&run.(&1)))
          &bind(run.(&1), acc)

        branch, acc ->
          run = compose_thorns(thorns, bind(&branch.run(&1)))
          &bind(run.(&1), acc)
      end)

    compose_thorns(
      roots,
      bind(fn state ->
        composition.(state)
      end)
    )
  end

  @doc false
  @spec compose_thorns([Entangle.Thorn.t()], (result -> result)) :: (state -> result)
  defp compose_thorns(thorns, first) do
    Enum.reverse(thorns)
    |> Enum.reduce(&first.({:ok, &1}), fn
      {run, _}, next -> run.(next)
      thorn, next when is_atom(thorn) -> thorn.run(next)
    end)
  end
end
