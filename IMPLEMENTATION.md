- [Foundation DB Notes](#foundation-db-notes)
- [**Directories**](#directories)
    - [*Node (Vertex)*](#node-vertex)
        - [**Properties**](#properties)
            - [*Serialize format*](#serialize-format)
            - [*E.g*](#eg)
        - [**Property indexes**](#property-indexes)
            - [*Serialize format*](#serialize-format)
        - [**Out Edges**](#out-edges)
            - [*Serialize format*](#serialize-format)
        - [**Out Edges Indexes**](#out-edges-indexes)
            - [*Serialize format*](#serialize-format)
        - [**In Edges**](#in-edges)
            - [*Serialize format*](#serialize-format)
    - [*Edge*](#edge)
        - [**Properties**](#properties)
            - [*Serialize format*](#serialize-format)
    - [*Implementation Notes*](#implementation-notes)
        - [**Primitives serialization**](#primitives-serialization)
    - [Known Issues/Limitations](#known-issueslimitations)
        - [Recursive queries](#recursive-queries)
            - [Possible Solution/s:](#possible-solutions)
        - [Pattern of large amounts of relationships](#pattern-of-large-amounts-of-relationships)
            - [Possible Solution/s:](#possible-solutions)

# Foundation DB Notes

Nomure is built on top of FoundationDB, to understand the way of serializing things, check out the links for more info

[FoundationDB architecture](https://apple.github.io/foundationdb/architecture.html)

[FoundationDB layer concepts](https://apple.github.io/foundationdb/layer-concept.html)

[FoundationDB data modeling](https://apple.github.io/foundationdb/data-modeling.html)

# **Directories**

## *Node (Vertex)*

### **Properties**

Primitive types of the Node

#### *Serialize format*

`(uid, property_name) = value`

#### *E.g* 

An User datamodel, the primitive properties could be `age`, `name`, `birthday`

---

### **Property indexes**

Indexes for the properties

#### *Serialize format*

`(property_name, value, uid) = ''`

---

### **Out Edges** 

Relationship properties, reference other nodes and the connection edges

#### *Serialize format*

`(uid, edge_name, edge_uid) = relation_node_uid` 

---

### **Out Edges Indexes** 

Indexing edges of the out edges

#### *Serialize format*

`(uid, edge_name, edge_property_name, value, edge_id) = out_relation_node_uid`

---

### **In Edges** 

Reverse of the out edges, acts like and index for relationships 

#### *Serialize format*

`(relation_node_uid, edge_name, uid) = edge_uid`

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
 
    32 bits big endian

- `float` 
 
    64 bits big endian

- `bool`

    single byte

- `date` 
 
    tuple with the format `{year, month, day, hour, minute, second}`

- `enum` 
 
    bit-string

- `string` 
 
    bit-string

- `uid` 

    128 bites little endian


## Known Issues/Limitations

### Recursive queries

In nested queries the childs might fetch parent nodes that are already loaded in the first steps of query request, *that's a big problem for performance and resource usage*.

#### Possible Solution/s:
Use the Facebook Dataloader, it caches the requests over the query, is a good way solve this problem and improve the performance of the queries (even more if are computationally expensive, like sum of values, but at the moment of writing this Nomure doesn't support it)

### Pattern of large amounts of relationships

One of the problems that Graph databases solves is analysis over large amounts of relationships, a good example is described on facebook (at https://code.fb.com/data-infrastructure/dragon-a-distributed-graph-query-engine/):

Suppose we follow a really famous user, with millions of followers and I want to know which of my friends follow that person, **this is super expensive in the way that Nomure works right now**, it can be distributed operations over a range of data (sharding?), due to the nature of Elixir and FDB this is "easy", but is an advance topic to cover.

This problem is simple if I have a few friends, in that case I can iterate over my friends and check if the user key contains my friends and get the result, but if I have millions of friends as the user does it became really expensive with the methods we have now.

There are a lot of graph alorithms out there, but the real chanllenge is to implement then with the use of FDB.

#### Possible Solution/s:
Not planned yet, **For the moment** this functionality is out of the scope for Nomure