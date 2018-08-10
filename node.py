import struct
from enum import Enum

import fdb

fdb.api_version(520)

database = fdb.open()


class NodeStorage:
    """
    Contains the Node in memory class based on their name

    {'node_name': Node instance}
    """
    nodes = {}


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

    def __init__(self, kind, node_name, edge_properties=None, indexes=None):
        NodeProperty.__init__(self, kind, indexes)
        if edge_properties is None:
            edge_properties = {}
        self.node_name = node_name
        self.edge_properties = edge_properties


class Graph:
    """
    The basic implementations and common functions for the graph properties
    """

    def __init__(self, directory, attributes):
        self.properties = attributes
        self.directory = directory

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
            return isinstance(value, bytes) or (isinstance(value, dict) and 'edge' in value and 'data' in value)
        else:
            return False

    def set(self, tr, data):
        for att_name, value in data.items():
            if self.check_props_values(att_name, value):
                continue
            return None
        return self.set_data(tr, data)

    @fdb.transactional
    def set_data(self, tr, data):
        """Must be declared in any child class and implemented, since python can't force it I'll advice here

        :param tr: Database instance
        :param data: Dictionary with the data to be set in the database
        :return: A unique identifier of the set data
        """
        return None

    @fdb.transactional
    def next_count(self, tr):
        """Get the next node uid.
        The uid is serialized as 64 bits unsigned integer by the flag '<Q'

        uid is global and shared by all the nodes
        """
        tr.add(self.directory.pack(('uid',)), struct.pack('<Q', 1))
        return tr.get(self.directory.pack(('uid',)))

    @staticmethod
    def get_node_by_name(node_name):
        """Return the Node subspace based on the node_name
        """
        if node_name not in NodeStorage.nodes:
            return None
        return NodeStorage.nodes[node_name]

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
        elif isinstance(value, (int, float)):
            return value
        else:
            # TODO fbd error handling, no valid value so throw an error
            return None

    @staticmethod
    def reset_transaction(tr):
        tr.reset()
        return None


class Edge(Graph):
    # Edge:
    # (uid, (edge_attribute_name, attribute_value)) = 'node_name'

    directory = fdb.directory.create_or_open(database, ('edge',))

    def __init__(self, properties):
        super().__init__(Edge.directory, properties)
        self.properties = self.directory['E']

    @fdb.transactional
    def set_data(self, tr, data):
        uid = self.next_count(tr)
        tr[self.properties[uid][b'uid']] = uid
        if data is not None:
            for property_name, value in data.items():
                # Ignore any given uid field, since is autogenerated
                if property_name in Node.reserved_edge_names:
                    continue

                # Get the fbd version of the given value
                fdb_value = self.get_as_fdb_value(value)

                if fdb_value is None:
                    return self.reset_transaction(tr)

                tr[self.properties[uid][property_name.encode()]] = value
        return uid


class Node(Graph):
    # Node Properties:
    # (uid, attribute_name, value) = ''
    # For edge connection:
    # (uid, attribute_name, edge_uid) = 'uid', The uid is saved here, not in the edge, edge only contains the
    # relationship properties data

    # for query node properties {'name': None}
    # for query edge properties {'name': 'edge'}

    # Edge:
    # (uid, (edge_attribute_name, attribute_value)) = 'node_name'

    # Custom node properties
    # __node_name__ returns the given node name, useful for Union types in GraphQL
    db = database
    directory = fdb.directory.create_or_open(db, ('graph',))
    reserved_edge_names = ['uid', '__node_name__']

    # Begin as an empty dict, once the schema is parsed must be filled with the schemas info
    schemas = {}

    def __init__(self, node_name, schema):
        super().__init__(Node.directory, schema)
        # node name
        self.name = node_name
        # graph instance
        self.graph = Node.directory[node_name]
        # edge instance
        self.edges = self.graph['E']
        # inverse instance
        self.inverse = self.graph['I']
        # indexes
        self.indexes = self.graph['IN']
        # Set the schema in the global schema storage
        if node_name in Node.schemas or node_name in NodeStorage.nodes:
            raise KeyError("The given node_name is already set in the schema, please check duplication issues")
        Node.schemas[node_name] = schema
        NodeStorage.nodes[node_name] = self

    @property
    def props(self):
        """The node schema properties

        :return: The node properties schema
        """
        return Node.schemas[self.name]

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

    def get(self, tr, node_uid, fields):
        if node_uid is None or not self.props_exists(fields, self.props):
            return None
        return self.get_node(tr, node_uid, fields)

    def get_node_fields(self, tr, node_uid, fields, props, node_property):
        result = {}
        for property_name, value in fields.items():
            if property_name == '__node_name__':
                result[property_name] = self.name
            elif property_name != 'uid' and isinstance(props[property_name], WithNodeProperty):
                # is a node query subsequent data
                result_nodes = []
                for relation_edge_uid, relation_node_uid in tr[node_property[node_uid][property_name.encode()].range()]:
                    # TODO edge data query format
                    node_props = Node.schemas[props[property_name].node_name]
                    relation_node = Node.get_node_by_name(props[property_name].node_name)

                    # TODO reset or ignore the field?
                    if relation_node is None:
                        return self.reset_transaction(tr)

                    result_nodes.append(self.get_node_fields(
                        tr, relation_node_uid, value, node_props, relation_node.edges))
                result[property_name] = result_nodes
            else:
                # is a node_property
                result[property_name] = tr[node_property[node_uid][property_name.encode()]]
        return result

    def set_node_property(self, tr, value, edge_name, uid):
        """ Set a property node with the edge info as well

        :param tr: Database instance
        :param value: Node and Edge Data
        :param edge_name: The Edge name
        :param uid: Current Node uid
        :return: A boolean telling if the function was a success or not
        """
        # Avoid spelling errors
        e_key = 'edge'
        d_key = 'data'

        # must be dict, the 'data' key set the node info, the 'edge' key set the edge info

        # if edge is none, check the properties of the edge are empty, if don't check for null, if not null
        # reset transaction

        # if edge is not a dict, must be a valid uid binary, if not reset transaction
        if not isinstance(value, dict) or d_key not in value or e_key not in value or not value[d_key]:
            return False

        # Not given edge values but the edge contains properties, reset transaction
        if not value[e_key] and self.props[edge_name].edge_properties != {}:
            return False

        # Set the edge data
        edge_data = value[e_key]
        edge = Edge(self.props[edge_name].edge_properties)

        if edge_data is None:
            edge_uid = edge.set_data(tr, None)
        else:
            edge_uid = edge.set(tr, edge_data)

        # if set fails we reset the tr
        if edge_uid is None:
            return False

        node_data = value[d_key]
        relation_node = Node.get_node_by_name(self.props[edge_name].node_name)
        if relation_node is None:
            return False

        if isinstance(node_data, bytes):
            # Set the key, the problem is to know the node_name
            # (uid, attribute_name, edge_uid) = 'uid'
            if not tr[relation_node.edges[node_data][b'uid']].present():
                return False
            tr[self.edges[uid][edge_name.encode()][edge_uid]] = node_data
        elif isinstance(node_data, dict):
            relation_uid = relation_node.set(tr, node_data)
            if relation_uid is None:
                return False
            tr[self.edges[uid][edge_name.encode()][edge_uid]] = relation_uid
        else:
            return False
        return True

    @fdb.transactional
    def set_data(self, tr, values):
        """ Check the given dictionary with the values and set them into the database, it sets automatically the
        uid field and ignore any uid field given in the dictionary.

        :param tr: The database transaction
        :param values: Dictionary containing the properties values to set
        :return: The unique node id
        """

        # TODO this function can be split in many functions, but I'm not sure how the `transactional` decorator
        # will handle it

        uid = self.next_count(tr)
        tr[self.edges[uid][b'uid']] = uid
        for edge_name, value in values.items():
            # Ignore any given uid field, since is autogenerated
            if edge_name in self.reserved_edge_names:
                continue

            if self.props[edge_name].kind == PropertyKind.NODE:
                if self.set_node_property(tr, value, edge_name, uid) is False:
                    return self.reset_transaction(tr)
            else:
                # Get the fbd version of the given value
                fdb_value = self.get_as_fdb_value(value)

                if fdb_value is None:
                    return self.reset_transaction(tr)

                # Check if the prop is unique, if exist  reverts the transaction
                if NodePropertyIndexes.UNIQUE in self.props[edge_name].indexes:
                    # TODO there must be a better way to handle this validation
                    tr_range = self.indexes[edge_name.encode()][fdb_value].range()
                    for _, _ in tr.get_range(tr_range.start, tr_range.stop, limit=1):
                        return self.reset_transaction(tr)
                # Set the index
                # TODO must set the index as a declared index and not automatically?
                tr[self.indexes[edge_name.encode()][fdb_value][uid]] = b''
                tr[self.edges[uid][edge_name.encode()]] = fdb_value
        return uid

    @fdb.transactional
    def get_all(self, tr, node_uid):
        if node_uid is None:
            return None
        result = {}
        for edge_name, edge_properties in self.props.items():
            if edge_properties.kind == PropertyKind.NODE:
                # TODO query edge info
                node_result = []
                for _, relation_node_uid in tr[self.edges[node_uid][edge_name.encode()].range()]:
                    node_result.append(relation_node_uid)
                edge_value = node_result
            else:
                edge_value = tr[self.edges[node_uid][edge_name.encode()]]
            result[edge_name.encode()] = edge_value
        if result == {}:
            return None
        result[b'uid'] = tr[self.edges[node_uid][b'uid']]
        return result

    @fdb.transactional
    def get_node(self, tr, node_uid, fields):
        return self.get_node_fields(tr, node_uid, fields, self.props, self.edges)

    @fdb.transactional
    def get_edge_value(self, tr, node_uid, edge_name):
        return tr[self.edges[node_uid][edge_name.encode()]]

    @fdb.transactional
    def get_by(self, tr, edge_name, value):
        fdb_value = self.get_as_fdb_value(value)

        if fdb_value is None:
            return self.reset_transaction(tr)

        # check edge node indexes, if have unique return the first element, if not return the list
        result = [self.get_all(tr, self.indexes.unpack(k)[-1])
                  for k, _ in tr[self.indexes[edge_name.encode()][fdb_value].range()]]
        if not result:
            return None
        return result

    @fdb.transactional
    def clear_subspace(self, tr, subspace):
        tr.clear_range_startswith(subspace.key())
