# Welcome to the Nomure (オオカミ*の群れ*) database repository!

This is the database we use at [Okami](https://www.okami.io)!

Is powered by [FoundationDB](https://www.foundationdb.org) and is mean to be **graph database** for all our needs, 
check the source for more info!

***This project is a work in progress, be careful using it***

# Features/RoadMap

- [ ] Property Values
    - [ ] I18N Strings
    - [ ] Primitive types List
    - [ ] Enums
    - [ ] Json (Dictionary)

- [ ] Node implementation
    - [x] Set data
    - [ ] Get data
        - [x] get_all
        - [x] get_by_edge_name
        - [x] get_by_fields
        - [ ] get_by_reverse
    - [x] Index property edges
    - [x] Inverse Node support `(relation.uid, "edge_name", node.uid) = node_relation_edge.uid`
    - [ ] Update support
    - [ ] Delete support

- [ ] Edge implementation
    - [x] Set data
    - [x] Get data
    - [ ] Index property edges
    - [ ] Update support
    - [ ] Delete support

- [ ] A better error handling: right now the errors are covered, but returning None making it difficult to know 
why is the problem

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

- [ ] Network Protocol implementation
    - [ ] GraphQL (standard query, mutation language) [this uses the connection 
    features of GraphQL to make it easier to query graph data]
        - [ ] SDL (GraphQL)
            - [ ] Parsing
            - [ ] Definition and exposing as custom schema for query and mutation
    - [ ] Gremlin (complex query for things like recommendation engines etc)

- [ ] More tests
