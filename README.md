# Nomure

# Welcome to the Nomure (オオカミ*の群れ*) repository!

This is the main database we use at [Okami](https://www.okami.io)!

The repo acts as a Graph layer for [FoundationDB](https://www.foundationdb.org)!

***This project is a work in progress, be careful using it***


# Motivation

Graph databases are amazing, from the first time that I knew of its features and use I was fascinated, but most implementations of them were used at a big scale on companies like Google and Facebook, with its use being more for analysis than for storage.

I wanted to have single database that could behave like a graph database, but that it had all the guarantees of a database like Postgres, was cheap and easy to scale, but in the world of graph databases it is really difficult to find all that in one place... Until I came across FoundationDB and from there Nomure was born.

I thought it would be a great project and thanks to how FoundationDB is designed it would allow me to achieve the features that I need to use in my application, of course, it can not be compared to everything that other databases have, but it has exactly everything I need for my use case at the moment I'm creating Okami. I will be very happy if it works for your project too!


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

