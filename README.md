# Welcome to the Nomure (オオカミ*の群れ*) database repository!

This is the database we use at [Okami](https://www.okami.io)!

Is powered by [FoundationDB](https://www.foundationdb.org) and is mean to be graph database for all our needs, 
check the source for more info!

*The database code still in development, be careful using it*

# RoadMap

- Vertex implementation
    - set data
    - get data

- A better error handling: right now the errors are covered, but returning None making it difficult to know 
why is the problem

- `where` query support 
    - Datetime sorting and query

- SDL parsing

- Network Protocol implementation