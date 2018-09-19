defmodule Entangle.Thorn do
  @moduledoc """
  Thorns are modules which can be inserted as middleware inbetween branches and entangled compositions.
  You can create a seperate module that uses `Entangle.Thorn` and defines its run callback,
  and add it into a function composition passing only the module name.
  Alternatively you can use the `Entangle.Thorn.grow/2` function to freely refer to functions defined in other modules.

  ## Examples

      iex> defmodule Mod.Composition.ThornTest do
      ...>   use Entangle.Thorn, layers: [:*]
      ...>
      ...>   @impl Entangle.Thorn
      ...>   def run(next) do
      ...>     fn state ->
      ...>       if state < 10, do: next.(state + 10), else: {:ok, state}
      ...>     end
      ...>   end
      ...> end
      ...>
      ...> defmodule Mod.Composition.ThornTestCompositions do
      ...>   use Entangle.Entangler, settings: %Entangle.Seed{thorns: [Mod.Composition.ThornTest]}
      ...>
      ...>   def add(x), do: {:ok, x + 1}
      ...>
      ...>   entangle :add3, [
      ...>     branch(&__MODULE__.add/1),
      ...>     branch(&__MODULE__.add/1),
      ...>     branch(&__MODULE__.add/1)
      ...>   ]
      ...> end
      ...>
      ...> Mod.Composition.ThornTestCompositions.add3(1)
      {:ok, 12}

  """

  alias Entangle.Entangler

  @typedoc """
  Options that can be passed upon using this module, or as second argument of the `Entangle.Thorn.grow/2` function.
  """
  @type option :: {:layers, [atom]}

  @type options :: [option]

  @typedoc """
  Type of a thorn (middleware) that can be set in the Engangle.Seed settings module.
  It can either be the module name of a module using `Entangle.Thorn`,
  or a tuple with a reference to a pre-defined function and a keyword list of options.
  """
  @type t :: module | {((Entangler.state() -> Entangler.result()) -> Entangler.result()), options}

  @doc """
  The callback that contains the middlewares logic.
  """
  @callback run((Entangler.state() -> Entangler.result())) :: Entangler.result()

  @doc """
  Callback to obtain the layers this module is attached to.
  The implementation will be automatically generated on use.
  """
  @callback layers() :: [atom]

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Entangle.Thorn

      Module.register_attribute(__MODULE__, :layers, [])
      @layers Keyword.get(opts, :layers, [:*])

      @doc false
      @impl Entangle.Thorn
      def run(next) do
        fn state -> next.(state) end
      end

      @doc false
      @impl Entangle.Thorn
      def layers(), do: @layers

      defoverridable run: 1
    end
  end

  @doc """
  Creates a thorn (middleware) for the function composition on the fly.
  Referred functions should be predefined and passed in the form `Module.function_name/arity`.

      iex> defmodule Mod.Composition.GrowTestSeed do
      ...>   use Entangle.Seed
      ...>
      ...>   def max_ten(next) do
      ...>     fn
      ...>       state when state <= 10 -> next.(state)
      ...>       state -> {:ok, state}
      ...>     end
      ...>   end
      ...>
      ...>   thorn grow(&__MODULE__.max_ten/1)
      ...> end
      ...>
      ...> defmodule Mod.Composition.GrowTestComposition do
      ...>   use Entangle.Entangler, settings: Mod.Composition.GrowTestSeed
      ...>
      ...>   def add_five(x), do: {:ok, x + 5}
      ...>
      ...>   entangle :add15, [
      ...>     branch(&__MODULE__.add_five/1),
      ...>     branch(&__MODULE__.add_five/1),
      ...>     branch(&__MODULE__.add_five/1)
      ...>   ]
      ...> end
      ...>
      ...> Mod.Composition.GrowTestComposition.add15(1)
      {:ok, 11}

  """
  @spec grow(
          ((Entangler.state() -> Entangler.result()) ->
             (Entangler.state() -> Entangler.result())),
          options
        ) :: t
  def grow(fun, options \\ []) do
    {fun, options}
  end
end
