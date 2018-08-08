import struct
from enum import Enum

import fdb

fdb.api_version(520)

database = fdb.open()


class PropertyKind(Enum):
    """
    Describes the possible types to be set as a value in foundation db and this layer
    """
    STRING = 1
    INT = 2
    FLOAT = 3
    NODE = 4


class NodePropertyIndexes(Enum):
    """
    Describes the possible indexes that can be applied to the property values
    """
    UNIQUE = 1


class NodeProperty:
    """
    Represents a Node property, it defines the value kind (static type) and the possible indexes for that property
    """

    def __init__(self, kind, indexes=None):
        if indexes is None:
            indexes = []
        self.kind = kind
        self.indexes = indexes


class WithNodeProperty(NodeProperty):
    """
    Override of the NodeProperty adding info about the connected Node, this represents a property with the Node type
    Takes the node name as an additional parameter
    """

    def __init__(self, kind, node_name, vertex_properties, indexes=None):
        NodeProperty.__init__(self, kind, indexes)
        self.node_name = node_name
        self.vertex_properties = vertex_properties


class Graph:
    """
    The basic implementations and common functions for the graph properties
    """

    def __init__(self, directory, attributes):
        self.properties = attributes
        self.directory = directory

    @fdb.transactional
    def next_count(self, tr):
        """Get the next edge uid.
        The uid is serialized as 64 bits unsigned integer by the flag '<Q'

        uid is global and shared by all the nodes
        """
        tr.add(self.directory.pack(('uid',)), struct.pack('<Q', 1))
        return tr.get(self.directory.pack(('uid',)))

    def check_props_values(self, key, value):
        """Check the properties and find if the given key and values are correct to be added in the database

            :param key: The property name
            :param value: The value to be setup
            :return: A boolean, False when there's an error, or True when everything is fine with the validation
        """
        if key not in self.properties:
            return False
        elif self.is_valid_value(key, value):
            return True
        else:
            return False

    def is_valid_value(self, key, value):
        """Check if the given value is valid to be set in the database

        :param key: The property name
        :param value: The value to be evaluated
        :return: A boolean telling if is correct or not
        """
        kind = self.properties[key].kind
        if kind == PropertyKind.STRING:
            return isinstance(value, str)
        elif kind == PropertyKind.INT or kind == PropertyKind.FLOAT:
            return value.isdigit()
        elif kind == PropertyKind.NODE:
            return isinstance(value, bytes)
        else:
            return False

    @fdb.transactional
    def set_data(self, tr, data):
        """Must be declared in any child class and implemented, since python can't force it I'll advice here

        :param tr: Database instance
        :param data: Dictionary with the data to be set in the database
        :return: A unique identifier of the set data
        """
        return None

    def set(self, tr, data):
        for att_name, value in data.items():
            if self.check_props_values(att_name, value):
                continue
            return None
        return self.set_data(tr, data)


class Vertex(Graph):
    # Vertex:
    # (uid, (vertex_attribute_name, attribute_value)) = 'node_name'

    directory = fdb.directory.create_or_open(database, ('vertex',))

    def __init__(self, attributes):
        super().__init__(Vertex.directory, attributes)
        self.in_node = 0
        self.out_node = 0

    @fdb.transactional
    def set_data(self, tr, data):
        # TODO
        pass


class Node(Graph):
    # Node Properties:
    # (uid, attribute_name, value) = ''
    # For vertex connection:
    # (uid, attribute_name, vertex_uid) = 'uid', The uid is saved here, not in the vertex, vertex only contains the
    # relationship properties data

    # for query node properties {'name': None}
    # for query vertex properties {'name': 'vertex'}

    # Vertex:
    # (uid, (vertex_attribute_name, attribute_value)) = 'node_name'

    # Custom node properties
    # __node_name__ returns the given node name, useful for Union types in GraphQL
    db = database
    directory = fdb.directory.create_or_open(db, ('graph',))

    # Begin as an empty dict, once the schema is parsed must be filled with the schemas info
    schemas = {}

    def __init__(self, node_name, schema):
        super().__init__(Node.directory, schema)
        # node name
        self.name = node_name
        # graph instance
        self.graph = Node.directory[node_name]
        # edge instance
        self.edge = self.graph['E']
        # inverse instance
        self.inverse = self.graph['I']
        # indexes
        self.indexes = self.graph['IN']
        # Set the schema in the global schema storage
        if node_name in Node.schemas:
            raise KeyError("The given node_name is already set in the schema, please check duplication issues")
        Node.schemas[node_name] = schema

    @property
    def props(self):
        """The node schema properties

        :return: The node properties schema
        """
        return Node.schemas[self.name]

    @fdb.transactional
    def set_data(self, tr, values):
        """ Check the given dictionary with the values and set them into the database, it sets automatically the
        uid field and ignore any uid field given in the dictionary.

        :param tr: The database transaction
        :param values: Dictionary containing the properties values to set
        :return: The unique node id
        """

        uid = self.next_count(tr)
        tr[self.edge[uid][b'uid']] = uid
        for vertex, value in values.items():
            # Ignore any given uid field, since is autogenerated
            if vertex == "uid" or vertex == '__node_name__':
                continue

            # Get the fbd version of the given value
            fdb_value = self.get_as_fdb_value(value)

            if fdb_value is None:
                tr.reset()
                return None

            # Check if the prop is unique, if exist  reverts the transaction
            if NodePropertyIndexes.UNIQUE in self.props[vertex].indexes:
                # check the value does not exist in the database
                # TODO there must be a better way to handle this validation
                for _, _ in tr[self.indexes[vertex.encode()][fdb_value].range()]:
                    # if value exist reset the transaction, we do no cancel since it throw an error
                    tr.reset()
                    return None

            if self.props[vertex].kind == PropertyKind.NODE:
                # must be dict, the 'data' key set the node info, the 'vertex' key set the vertex info

                # if vertex is none, check the properties of the vertex are empty, if don't check for null, if not null
                # reset transaction

                # if vertex is not a dict, must be a valid uid binary, if not reset transaction
                if not isinstance(value, dict) or 'data' not in value or 'vertex' not in value:
                    tr.reset()
                    return None
                pass  # TODO
            else:
                # Set the index
                # TODO must set the index as a declared index and not automatically?
                tr[self.indexes[vertex.encode()][fdb_value][uid]] = b''
                tr[self.edge[uid][vertex.encode()]] = fdb_value

        return uid

    @fdb.transactional
    def get_all(self, tr, edge_id):
        if edge_id is None:
            return None
        result = {self.edge.unpack(k)[-1]: v for k, v in tr[self.edge[edge_id].range()]}
        if result == {}:
            return None
        return result

    def get(self, tr, edge_id, fields):
        if edge_id is None or not self.props_exists(fields, self.props):
            return None
        return self.get_edge(tr, edge_id, fields)

    @fdb.transactional
    def get_edge(self, tr, edge_id, fields):
        return self.get_edge_fields(tr, edge_id, fields, self.props, self.edge)

    @fdb.transactional
    def get_vertex_value(self, tr, edge_id, vertex):
        return tr[self.edge[edge_id][vertex.encode()]]

    @fdb.transactional
    def get_by(self, tr, vertex, value):
        fdb_value = self.get_as_fdb_value(value)

        if fdb_value is None:
            tr.reset()
            return None

        # check vertex node indexes, if have unique return the first element, if not return the list
        result = [self.get_all(tr, self.indexes.unpack(k)[-1])
                  for k, _ in tr[self.indexes[vertex.encode()][fdb_value].range()]]
        if not result:
            return None
        return result

    @fdb.transactional
    def clear_subspace(self, tr, subspace):
        tr.clear_range_startswith(subspace.key())

    @staticmethod
    def get_edge_by_node_name(node_name):
        """Return the Edge subspace based on the node_name

        WARNING: This function does not check if the subspace exist or not, so use it
        carefully
        """
        return Node.directory[node_name]['E']

    @staticmethod
    def get_as_fdb_value(value):
        """Check the value to be set up and return it intact or in the correct foundation db format

            String: encode it to bytes
            Bytes:  return the raw value
        """
        if isinstance(value, str):
            return value.encode()
        elif isinstance(value, bytes):
            return value
        else:
            # TODO fbd error handling, no valid value so throw an error
            return None

    def props_exists(self, fields, props):
        """Checks if the given query fields exist in the given node and child
        """
        for k, v in fields.items():
            # the uid field is for internal use and all nodes shared it,
            # is not exposed in the props but exist internally
            if k == 'uid' or k == '__node_name__':
                continue
            if k not in props:
                return False
            if isinstance(props[k], WithNodeProperty):
                return self.props_exists(v, Node.schemas[props[k].node_name])
        return True

    def get_edge_fields(self, tr, edge_id, fields, props, edge):
        result = {}
        for vertex, value in fields.items():
            if vertex == '__node_name__':
                result[vertex] = self.name
            elif vertex != 'uid' and isinstance(props[vertex], WithNodeProperty):
                # is a node query subsequent data
                # TODO depending on how this is serialized we get the range
                # for uid, _ in tr[edge[edge_id][vertex.encode()].range()]:
                #     result[vertex] = self.get_edge_fields(
                #         tr, uid, value, Node.schemas[vertex], Node.get_edge_by_node_name(props[vertex].node_name))
                node_uid = tr[edge[edge_id][vertex.encode()]]
                node_props = Node.schemas[props[vertex].node_name]
                node_edge = Node.get_edge_by_node_name(props[vertex].node_name)
                result[vertex] = self.get_edge_fields(
                    tr, node_uid, value, node_props, node_edge)
            else:
                # is a property
                result[vertex] = tr[edge[edge_id][vertex.encode()]]
        return result
