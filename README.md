# Nomure

# Welcome to the Nomure (オオカミ*の群れ*) repository!

This is the main database we use at [Okami](https://www.okami.io)!

The repo acts as a Graph layer for [FoundationDB](https://www.foundationdb.org)!

***This branch is a rewrite in order to clean up the code, do not use it yet***

# Implementation

The project the following layers to make it work

- Graph:

    The graph layer for FDB, for specific details like serialization etc... check out the `IMPLEMENTATION.md` file


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nomure` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nomure, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/nomure](https://hexdocs.pm/nomure).

