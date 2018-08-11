# Welcome to the Nomure (オオカミ*の群れ*) database repository!

This is the database we use at [Okami](https://www.okami.io)!

Is powered by [FoundationDB](https://www.foundationdb.org) and is mean to be **graph database** for all our needs, 
check the source for more info!

***This project is a work in progress, be careful using it***

# Features/RoadMap

- [ ] Node implementation
    - [x] Set data
    - [x] Get data
        - [x] get_all
        - [x] get_by_edge_name
        - [x] get_by_fields
    - [x] Index property edges
    - [ ] Update support
    - [ ] Delete support

- [ ] Edge implementation
    - [x] Set data
    - [ ] Get data
    - [ ] Index property edges
    - [ ] Update support
    - [ ] Delete support

- [ ] A better error handling: right now the errors are covered, but returning None making it difficult to know 
why is the problem

- [ ] Query support

    - [ ] `where` 
        - [ ] Datetime storage
        - [ ] `>`
        - [ ] `<`
        - [ ] `==`
        - [ ] `>=`
        - [ ] `<=`
        - [ ] `and`
        - [ ] `or`

    - [ ] pagination support (cursor based)
        - [ ] `after`
        - [ ] `before`
        - [ ] `limit`

- [ ] Network Protocol implementation
    - [ ] GraphQL (standard query, mutation language) [this uses the connection 
    features of GraphQL to make it easier to query graph data]
        - [ ] SDL (GraphQL)
            - [ ] Parsing
            - [ ] Definition and exposing as custom schema for query and mutation
    - [ ] Gremlin (complex query for things like recommendation engines etc)

- [ ] More tests
