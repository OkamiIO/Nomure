# Nomure Schema Definition

This describes the posible schema definition types, by default all property definitions has a property name as key of a map containing the metadata of that property, by default this metadata are:

- `type` : key which describes the valid variable type

    `valid types` : 
    
    - `"string"`
    - `"integer"`
    - `"float"`
    - `"boolean"`
    - `"datetime"`
    - `"date"`
    - `"time"`
    - `"list"`
    - `"enum"`
    - `"node"`
    - `"node_list"`


- `index` : key which describes the possible indexes of that given type

    `valid types` : 

    - `nil` : default value, not indexed
    - `true` : index it with the default indexer of the given value
    - `"unique"` : index it with the default indexer but ensures is a unique value over all nodes

# Type specific definitions

## string

`index` : 

- "exact" : this index the exact same string, good uses could be the username or email of an user (tho I'd recommend using the `"unique"` index since those fields commonly are unique over the database)

- "term" : this index allow you to search the string doing term matching, search the given string inside other string, similar to "String.contains" in Elixir, but the algorithm normalize the string when indexing or querying

- "fulltext" : this is the most complete index, but the most expensive one, this perform the given steps for indexing and before query:

    - Tokenization (retrive the word boundaries)
    - Lowercase
    - String Normalization.
    - Language Stemming (remove redundant parts on the string like "ing" on english language)
    - Remove stop words

## enum

`values` : This is a required field within `enum` definitions, enums are static string names that point out to a static integer in order to minimize the value sizes inside the database

    eg: %{"busy" => 0, "free" => 1}

    Let's think a user has the field status as enum value, you set the user like %{status: "busy"}, in the database the value will be 0 instead of being "busy" (1 byte value instead of 4 bytes), if you query the field you'll get the "busy" value not the 0 one


# Non indexed types

- "list"