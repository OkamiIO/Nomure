# Nomure

# Welcome to the Nomure (オオカミ*の群れ*) database repository!

This is the main database we use at [Okami](https://www.okami.io)!

It's main purpose is to server as a main database just like you use Postgres or Mysql, but as a Graph data structure

The repo acts as a Graph layer for [FoundationDB](https://www.foundationdb.org)!

***This project is a work in progress, be careful using it***


# Motivation

Graph databases are amazing, from the first time that I knew of its operation and use I was fascinated, but most implementations of the Graph databases where used at a big scale on companies like Google and Facebook, with it's use beign more for analisys than storage.

The open source options need really computational (and cost) expensive storages like Cassandra, Big Table, custom in memory etc... (Janus Graph, Titan, Neo4J, Datastax. Neptune etc...) with the purpose of being used at large scale projects for analysis and again not for storage (due to limitations like ACID and transactions)

I wanted something like Posgres (there is agensgraph, but the documentaion is messy and they are focus on big companies as well) that I can use in my small project with limited in economic resources, the only option was Dgraph, an startup open source graph database that is mean to be a fully distributed graph database with all the consistency features of a database like PostgreDB, but the development team was proud and self-centered and the project was affected by it with an unknown direction about the project, but was my only option at the time.

Then one day Apple decided to release FoundationDB a distributed ordered key value storage with amazing speed for transactions, ACID support and no need for expensive machines to be run, with the best potential to extend it to the need of your project requirements.

From here the idea of Nomure was born, a fully distributed Graph database with the consistency of a relational database without the need of really expensive machines to make it work.

Of course Nomure can't be compared with the big guys like Neo4j, Dgraph or Dragon, but it is just the perfect solution for the problems I'm facing at the moment of creating Nomure (I'm also trying to use already implemented solutions like the amazing Facebook articles on the topic), if it fits to your project as well be welcome to use it and contribute to make it a better database solution!


# Implementation

The project contains various layers to make it work

- ~~Network~~ (Out of the scope ATM):

    ~~Is the one encharged to get request from the internet and translate them into a
    query, mutation or subscription to data retrival to the fdb graph layer~~

    - ~~GraphQL:~~

        ~~The main network layer, everything you need about queries and mutations is here, it also is encharged of ensure the static types 
        in the schema for adding them into the graphql layer~~

    - ~~openCypher:~~
        
        ~~Is an advanced network layer for more complex queries and data analisys, such as recommendation systems~~

- Graph:

    The graph layer for FDB, for specific details, check out `IMPLEMENTATION.md` 


# Features/RoadMap

- [ ] Property Values
    - [x] ~~I18N Strings~~ (for this we need string index etc... To really have sense, otherwise is just a property with and @ and the language at the end)
    - [ ] Primitive types List
    - [x] ~~Enums~~ (Is just a string, we do not check types)
    - [x] ~~Dictionary~~ (Not in the roadmap)

- [ ] Index
    - [ ] Datetime
    - [x] String
    - [x] Integer
    - [x] Float
    - [ ] List
    - [x] ~~Map~~ (just use a node :D)

- [ ] Node implementation
    - [x] Set data
    - [ ] Get data
        - [ ] get_all
        - [ ] get_by_edge_name
        - [ ] get_by_fields
        - [ ] get_by_reverse
    - [x] Index property edges
    - [x] Inverse Node support `(relation.uid, "edge_name", node.uid) = node_relation_edge.uid`
    - [ ] Update support
    - [ ] Delete support

- [ ] Edge implementation
    - [x] Set data
    - [ ] Get data
    - [ ] Index property edges
    - [ ] Update support
    - [ ] Delete support

- [ ] Query support

    - [ ] `where` 
        - [ ] Datetime storage `{ year, month, day, seconds }`
        - [ ] `>` `KeySelector.first_greater_than(key)`
        - [ ] `<` `KeySelector.last_less_than(key)`
        - [ ] `==` `get_by_function(property, value, function = Function.equal)`
        - [ ] `>=` `KeySelector.first_greater_or_equal(key)`
        - [ ] `<=` `KeySelector.last_less_or_equal(key)`
        - [ ] `and`
        - [ ] `or`

    - [ ] `where_string`
        - [ ] `starts_with` serialize the string a tuple and set as a key, and use key selector for it

    - [ ] pagination support (cursor based)
        - [ ] `after` `Transaction.get_range(after_cursor, end, limit)`
        - [ ] `before` `Transaction.get_range(before_cursor, end, limit, reverse=True)`
        - [ ] `limit`
        - [ ] `first` `Transaction.get_range(start, end, limit=first)`
        - [ ] `count`

    - [ ] sorting
        - [ ] `order_asc` 
        - [ ] `order_des`

    - [ ] reverse node
    
    - [ ] functions
        - [ ] `min` `Transaction.get_range(start, end, limit=1, reverse=True)`
        - [ ] `max` `Transaction.get_range(start, end, limit=1)`

    - [ ] query optimization

- [x] ~~Network Protocol implementation~~
    - [ ] ~~GraphQL (standard query, mutation language) [this uses the connection 
    features of GraphQL to make it easier to query graph data]~~
        - [ ] ~~SDL (GraphQL)~~
            - [ ] ~~ Parsing~~
            - [ ] ~~Definition and exposing as custom schema for query and mutation~~
    - [ ] ~~Opengraph (complex query for things like recommendation engines etc)~~

- [ ] More tests

- [x] Ztandart data compression

    Depends on the use given by the serialization, but strings must be compressed

- [x] ~~Data Serialization setup (single blob or chunk, this describes the nodes properties)~~

    ~~So far our problem is the node uids, right now are 64 bit and we need to duplicate them in order to chunk
    the data, this could lead to big numbers on storage (and possibly memory) since we add this to the indexes
    and node relationships~~

    I aimed to do the chuck only version, blob can cause large values which might be larguer than FDB limitation

    References [FoundationDB Forum](https://forums.foundationdb.org/t/best-practice-of-storing-structs-should-i-pack-or-store-fields-separately/425/5)

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

