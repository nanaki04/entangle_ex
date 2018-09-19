defmodule Entangle.Branch do
  @moduledoc """
  The bread and butter building block of the function composition.
  You can create a seperate module that uses `Entangle.Branch` and defines its run callback,
  and add its name to the list of branches as the second argument of the `Entangle.Entangler.entangle/2` macro.
  Alternatively you can use the `Entangle.Branch.branch/2` function to freely refer to functions defined in other modules.

      iex> defmodule Mod.Composition.BranchTest do
      ...>   use Entangle.Branch, layers: [:*]
      ...>
      ...>   @impl Entangle.Branch
      ...>   def run(state), do: {:ok, state + 1}
      ...> end
      ...>
      ...> defmodule Mod.Composition.TestBranchComposition do
      ...>   use Entangle.Entangler
      ...>
      ...>   entangle :add3, [
      ...>     Mod.Composition.BranchTest,
      ...>     Mod.Composition.BranchTest,
      ...>     Mod.Composition.BranchTest
      ...>   ]
      ...> end
      ...>
      ...> Mod.Composition.TestBranchComposition.add3(1)
      {:ok, 4}

  """

  alias Entangle.Entangler

  @typedoc """
  Options that can be passed upon using this module, or as second argument of the `Entangle.Branch.branch/2` function.
  """
  @type option :: {:layers, [atom]}

  @type options :: [option]

  @typedoc """
  Type of a branch (function in a function composition) that can be added to the function list passed as second argument to the `Entangle.Entangler.entangle` macro.
  It can either be the module name of a module using `Entangle.Branch`,
  or a tuple with a reference to a pre-defined function and a keyword list of options.
  """
  @type t :: module | {(Entangler.state -> Entangler.result), options}

  @doc """
  The callback that contains the logic of the function to be used in a composition.
  """
  @callback run(Entangle.Entangler.state) :: Entangle.Entangler.result

  @doc """
  Callback to obtain the layers this module is attached to.
  The implementation will be automatically generated on use.
  """
  @callback layers() :: [atom]

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Entangle.Branch

      Module.register_attribute __MODULE__, :layers, []
      @layers Keyword.get(opts, :layers, :*)

      @doc false
      @impl Entangle.Branch
      def run(state), do: state

      @doc false
      @impl Entangle.Branch
      def layers(), do: @layers

      defoverridable [run: 1]
    end
  end

  @doc """
  Creates a branch for the function composition on the fly.
  Referred functions should be predefined and passed in the form `Module.function_name/arity`.
  """
  @spec branch((Entangler.state -> Entangler.result), options) :: t
  def branch(fun, opts \\ []) do
    {fun, opts}
  end
end
