- [Foundation DB Notes](#foundation-db-notes)
- [**Directories**](#directories)
  - [*Conventions*](#conventions)
- [Example data](#example-data)
  - [A -(C)-> B](#a--c--b)
  - [*Node (Vertex)*](#node-vertex)
    - [**Properties**](#properties)
      - [*Serialize format*](#serialize-format)
      - [*E.g*](#eg)
    - [**Property indexes**](#property-indexes)
      - [*Serialize format*](#serialize-format-1)
      - [*E.g*](#eg-1)
    - [**Out Nodes**](#out-nodes)
      - [*Serialize format*](#serialize-format-2)
      - [*E.g*](#eg-2)
    - [**Out Edges Indexes**](#out-edges-indexes)
      - [*Serialize format*](#serialize-format-3)
    - [**In Edges**](#in-edges)
      - [*Serialize format*](#serialize-format-4)
      - [*E.g*](#eg-3)
  - [*Edge*](#edge)
    - [**Properties**](#properties-1)
      - [*Serialize format*](#serialize-format-5)
  - [*Implementation Notes*](#implementation-notes)
    - [**Primitives serialization**](#primitives-serialization)
  - [Known Issues/Limitations](#known-issueslimitations)
    - [Recursive queries](#recursive-queries)
      - [Possible Solution/s:](#possible-solutions)
    - [Pattern of large amounts of relationships (Secondary indexes etc)](#pattern-of-large-amounts-of-relationships-secondary-indexes-etc)
      - [Possible Solution/s:](#possible-solutions-1)

# Foundation DB Notes

Nomure is built on top of FoundationDB, to understand the way it works, check out the links for more info

[FoundationDB architecture](https://apple.github.io/foundationdb/architecture.html)

[FoundationDB layer concepts](https://apple.github.io/foundationdb/layer-concept.html)

[FoundationDB data modeling](https://apple.github.io/foundationdb/data-modeling.html)

# **Directories**

## *Conventions*

`node_name` : `string` describing the name of the node

`node_uid` : global autoincremented unique `integer` id

`uid` : `(node_name, node_uid)`

# Example data

## A -(C)-> B

Where `A` and `B` are nodes/vertex and `C` is an Edge

## *Node (Vertex)*

### **Properties**

Primitive types of the Node

#### *Serialize format*

`(uid, property_name) = value`

#### *E.g* 

An User datamodel, the primitive properties could be `age`, `name`, `birthday` and their respective value

---

### **Property indexes**

Secondary property index

#### *Serialize format*

`(node_name, property_name, value, node_uid) = ''`

#### *E.g* 

Give me all nodes of the node name `A` with the property name `y` and the value `z`

---

### **Out Nodes** 

Relationship properties, reference other nodes 

#### *Serialize format*

`(uid, edge_name, uid) = ''` 

#### *E.g* 

Give me all the vertex that go from "A"

---

### **Out Edges Indexes** 

Indexing edges of the out edges

#### *Serialize format*

`(uid, edge_name, edge_property_name, value, edge_id) = uid`

---

### **In Edges** 

Reverse of the out edges, acts like and index for relationships 

#### *Serialize format*

`(uid, edge_name, uid) = ''`

#### *E.g* 

Give me all the vertex that go to "B"

Give me all the vertex that go to "B" through "C"

---

## *Edge*

### **Properties**

Primitive types of the Edge

#### *Serialize format*

`(uid, property_name) = value`


---

## *Implementation Notes*

By default all primitive (int, bool, date, enum) types are indexes except the `string` type 

### **Primitives serialization**

- `integer` 
 
    it could be 8, 16, 32, 64 bits depending the length of the integer

- `float` 
 
    32 bits big endian

- `bool`

    single byte

- `datetime` 
 
    tuple with the format `{year, month, day, hour, minute, second}`

- `date` 
 
    tuple with the format `{year, month, day}`

- `time` 
 
    tuple with the format `{hour, minute, second}`


- `enum` 

    bit-string

- `string` 
 
    unicode-string, it is compressed with zstd once the data reach certain length, length handled as a config value

- `uid` 

    tuple encoded `(string, integer)`


## Known Issues/Limitations

### Recursive queries

In nested queries the childs might fetch parent nodes that are already loaded in the first steps of query request, *that could be a big problem for performance and resource usage*.

#### Possible Solution/s:
Use the Facebook Dataloader, it caches the requests over the query, is a good way solve this problem and improve the performance of the queries (even more if are computationally expensive, like sum of values, but at the moment of writing this Nomure doesn't support it)

### Pattern of large amounts of relationships (Secondary indexes etc)

One of the problems that Graph databases solves is analysis over large amounts of relationships, a good example is described on facebook (at https://code.fb.com/data-infrastructure/dragon-a-distributed-graph-query-engine/):

Suppose we follow a really famous user, with millions of followers and I want to know which of my friends follow that person, **this is super expensive if the data is huge in the way that Nomure works right now**, it can be distributed operations over a range of data (sharding?), due to the nature of Elixir and FDB this is "easy", but is an advance topic to cover.

This problem is simple if I have a few friends, in that case I can iterate over my friends and check if the user key contains my friends and get the result, but if I have millions of friends as the user does it became really expensive with the methods we have now.

There are a lot of graph algorithms out there, but the real challenge is to implement then with the use of FDB.

#### Possible Solution/s:
Not planned yet, **For the moment** this functionality is out of the scope for Nomure