defmodule EntangleTest do
  use ExUnit.Case
  doctest Entangle.Entangler

  defmodule Entangle.Test.Branches do
    def add(x), do: {:ok, x + 1}
    def multiply(x), do: {:ok, x * 2}
    def subtract(x), do: {:ok, x - 1}
    def divide(0), do: {:error, "null division error"}
    def divide(x), do: {:ok, x / 2}

    def transform(next), do: &(next.(&1) * 10)
    def break(next), do: &(if &1 > 1, do: {:ok, &1}, else: next.(&1))
  end

  setup do
    layers = [:test, :prod, :dev]
    {:ok, layer_mask} = Layers.enable(layers, Layers.Mask.new(), Mix.env())
    {:ok, settings: %Elixir.Entangle.Seed{
      layers: layers,
      layer_mask: layer_mask,
      thorns: [],
      roots: []
    }}
  end

  test "make and use an entangler", state do
    defmodule Entangle.TestEntangler do
      use Elixir.Entangle.Entangler, seed: state[:settings]

      entangle :calculate, [
        branch(&Entangle.Test.Branches.add/1),
        branch(&Entangle.Test.Branches.add/1),
        branch(&Entangle.Test.Branches.multiply/1)
      ]
    end

    assert Entangle.TestEntangler.calculate(1) == {:ok, 6}
  end

  test "make an entangler with break function", state do
    settings = %Elixir.Entangle.Seed{state[:settings] | 
      thorns: [Elixir.Entangle.Branch.branch(&Entangle.Test.Branches.break/1)]
    }
    defmodule Entangle.TestBreakEntangler do
      use Elixir.Entangle.Entangler, seed: settings

      entangle :calculate, [
        branch(&Entangle.Test.Branches.add/1),
        branch(&Entangle.Test.Branches.add/1),
        branch(&Entangle.Test.Branches.multiply/1)
      ]
    end

    assert Entangle.TestBreakEntangler.calculate(1) == {:ok, 2}
  end

  test "make and use an entangler with error", state do
    defmodule Entangle.TestErrorEntangler do
      use Elixir.Entangle.Entangler, seed: state[:settings]

      entangle :calculate, [
        branch(&Entangle.Test.Branches.subtract/1),
        branch(&Entangle.Test.Branches.divide/1),
        branch(&Entangle.Test.Branches.subtract/1)
      ]
    end

    assert Entangle.TestErrorEntangler.calculate(2) == {:ok, -0.5}
    assert Entangle.TestErrorEntangler.calculate(1) == {:error, "null division error"}
  end

  test "make and use an entangler with layers", state do
    defmodule Entangle.TestLayerEntangler do
      use Elixir.Entangle.Entangler, seed: state[:settings]

      entangle :calculate, [
        branch(&Entangle.Test.Branches.subtract/1, layers: [:prod]),
        branch(&Entangle.Test.Branches.divide/1, layers: [:test, :dev]),
        branch(&Entangle.Test.Branches.subtract/1, layers: [:test])
      ]
    end

    assert Entangle.TestLayerEntangler.calculate(2) == {:ok, 0.0}
    assert Entangle.TestLayerEntangler.calculate(1) == {:ok, -0.5}
  end
end
