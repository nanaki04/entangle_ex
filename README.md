# Entangle

Function composition library for Elixir with the following features:

- compose multiple functions into one.
- add middleware inbetween every function call.
- add middleware around every composition.
- enable or disable middleware and specific function calls based on their associated layer.
- composable functions should return {:ok, result} or {:error, reason}.
- when a composed function returns {:error, reason}, the subsequent functions will be ignored.
- setup multiple settings modules, with middleware and layer settings, for easy reuse.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `entangle` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:entangle, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/entangle](https://hexdocs.pm/entangle).

