"""FoundationDB SimpleDoc Layer.
Provides the Doc class and associated classes for storing document-oriented
data in FoundationDB.
This layer serves as an example of how a simple, hierarchical data model can be
mapped to the ordered key-value store. The data model is a single document with
no size restrictions. Collections of related data are represented as
subdocuments of the root document.
A document in SimpleDoc is a collection of key-value pairs in which a value is
either a string or itself a document. In comparison to JSON, a document
approximately corresponds to a JSON object without JSON arrays and with JSON
values restricted to strings.
SimpleDoc also provides a powerful plugin capability that allows multiple levels
of plugins to manipulate the logical-to-physical mapping of operations.
The use of plugins is illustrated with an Index plugin that permits an
application to create indexes on documents using a pattern-matching syntax.
"""

import json
import threading
import weakref
from bisect import bisect_left

import fdb
import fdb.tuple

fdb.api_version(520)

doc_cache = weakref.WeakValueDictionary()


#######
# Doc #
#######

class Doc(object):
    """
    Doc is the basic unit of data, representing a document (or nested
    dictionary). It provides functions to get, set, and clear documents. In
    addition, it provides JSON export capability as both a simple operation
    and a streaming operation appropriate for large documents.
    """

    def __init__(self, path, parent, schema):
        self._path = path
        self._parent = parent
        self._schema = schema

    def __repr__(self):
        return "<Doc(" + ".".join(self._path[1:]) + ")>"

    def __getattr__(self, name):
        return self.get_child(name)

    def __setattr__(self, name, value):
        if name.startswith("_"):
            return object.__setattr__(self, name, value)
        self.set_child(name, value)

    def __getitem__(self, name):
        return self.get_child(name)

    def __setitem__(self, name, value):
        self.set_child(name, value)

    def __iter__(self):
        raise NotImplemented()

    def get_name(self):
        return self._path[-1]

    def get_child(self, name):
        p = self._path + (name,)
        ch = doc_cache.get(p, None)
        if ch:
            return ch
        doc_cache[p] = ch = Doc(p, self, self._schema.child(name))
        return ch

    def prepend(self):
        import os
        import struct
        from sys import maxsize
        zero_key = fdb.tuple.pack((self._path + (struct.pack(">Q", 0),)))
        last_key = fdb.tuple.pack((self._path + (struct.pack(">Q", maxsize),)))
        first_key = thread_local.tr.snapshot.get_key(fdb.KeySelector.first_greater_than(zero_key))
        if first_key > last_key:
            last_id = maxsize
        else:
            first_value = fdb.tuple.unpack(first_key)[-1]
            assert len(first_value) == 8, 'must be an 8-character string'
            last_id = struct.unpack('>Q', first_value)[0]

        counter = (last_id >> 16) - 1
        assert counter != 0, 'the counter has dropped to zero'
        randomness = struct.unpack('>H', os.urandom(2))[0]
        next_id = (counter << 16) - randomness
        name = struct.pack(">Q", next_id)
        return self.get_child(name)

    def get_descendant(self, path):
        node = self
        for name in path:
            node = node.get_child(name)
        return node

    def get_key(self):
        return fdb.tuple.pack(self._path)

    def set_child(self, name, value):
        self.get_child(name).set_value(value)

    def set_value(self, value):
        if isinstance(value, dict):
            self.clear_all()
            self.update(value)
        else:
            self._schema.value_plugins.set_value(self, value)

    def update(self, value):
        if isinstance(value, dict):
            for k, v in value.items():
                self.get_child(k).update(v)
        else:
            self._schema.value_plugins.set_value(self, value)

    def get_value(self):
        return self._schema.value_plugins.get_value(self)

    def get_present(self):
        return self.get_value() is not None

    def clear_all(self):
        self._schema.tree_plugins.clear_subtree(self)

    def get_json(self, pretty=False):
        x = ''.join(self.get_json_stream())
        if not pretty:
            return x
        return json.dumps(json.loads(str(x)), sort_keys=True, indent=4)

    def get_json_stream(self):
        yield "{"
        comma = False
        context = list(self._path)
        next_value = None

        def common_prefix_len(a, b):
            length = min(len(a), len(b))
            for index in range(length):
                if a[index] != b[index]:
                    return index
            return length

        def dumps(value):
            if isinstance(value, int):
                return str(value)
            if not isinstance(value, str):
                value = str(value)
            return json.dumps(value)

        for path, v in self._schema.tree_plugins.get_subtree(self, None, None):
            new_context = path
            cplen = common_prefix_len(context, new_context)
            if len(context) > cplen:
                if next_value is not None:
                    yield dumps(next_value)
                else:
                    yield "}"
                next_value = None
                yield "}" * (len(context) - cplen - 1)
                del context[cplen:]
                comma = True
            for i in range(len(context), len(new_context)):
                c = new_context[i]
                if comma:
                    yield ", "
                if next_value != None:
                    yield '{"__value__" : ' + dumps(next_value) + ', '
                    next_value = None
                comma = False
                yield dumps(str(c)) + " : "
                if i != len(new_context) - 1:
                    yield "{"
                context.append(c)
            next_value = v

        if next_value is not None:
            yield dumps(next_value)
        yield "}" * (len(context) - len(self._path))

    def get_children(self, begin=None, end=None):
        last = None
        if not begin:
            begin = ""
        for path, v in self._schema.tree_plugins.get_subtree(self, begin, end):
            cx = path[len(self._path)]
            if cx != last:
                yield self.get_child(cx)
                last = cx

    def get_descendant_values(self):
        """ Return all descendant keys of this key that have values, and the values """
        depth = len(self._path)
        for path, v in self._schema.tree_plugins.get_subtree(self, "", None):
            cx = path[depth:]
            yield (self.get_descendant(cx), v)


def transactional(func):
    """
    Defines a decorator to create transactional functions that operate on a
    simpledoc database. In contrast to @fdb.transactional, the function to be
    wrapped does not take a transaction or database as an argument. Rather,
    @simpledoc.transactional adds a transaction internally and stores it in a
    thread-local manner.
    """

    @fdb.transactional
    def tr_wrapper(tr, *args, **kw):
        try:
            thread_local.tr = tr
            return func(*args, **kw)
        finally:
            thread_local.tr = None

    def outer_wrapper(*args, **kw):
        if args and (isinstance(args[0], fdb.Transaction) or isinstance(args[0], fdb.Database)):
            return tr_wrapper(*args, **kw)
        elif not getattr(thread_local, 'tr'):
            raise Exception("Transactional function called without a database or transaction")
        else:
            return func(*args, **kw)

    return outer_wrapper


thread_local = threading.local()


###############
# PluginStack #
###############

class PluginStack(object):
    """
    Manages and applies the various layers of Plugins.
    """

    def __init__(self):
        self.all = []
        self.all_id = []

    def top(self):
        # Return the topmost plugin not in active_plugins and add it to active_plugins
        if not hasattr(thread_local, 'active_plugins') or not thread_local.active_plugins:
            plugin = self.all[-1]
            thread_local.active_plugins = [plugin.plugin_id]
        else:
            index = bisect_left(self.all_id, thread_local.active_plugins[-1]) - 1
            assert index >= 0
            plugin = self.all[index]
            assert plugin.plugin_id < thread_local.active_plugins[-1]
            thread_local.active_plugins.append(plugin.plugin_id)
        return plugin

    def untop(self, plugin):
        # Remove plugin from the top of active_plugins
        p = thread_local.active_plugins.pop()
        assert p == plugin.plugin_id

    def add(self, plugin):
        if self.all and self.all[-1] == plugin: return
        self.all.append(plugin)
        self.all_id.append(plugin.plugin_id)

    def copy(self, other):
        for p in other.all:
            self.add(p)

    # The public interface for PluginStack is the same as for
    # a single plugin. When these functions are called repentantly
    # by a given plugin, the next plugin down the stack is invoked.

    def get_value(self, node):
        p = self.top()
        try:
            r = p.get_value(node)
        finally:
            self.untop(p)
        return r

    def set_value(self, node, value):
        p = self.top()
        try:
            p.set_value(node, value)
        finally:
            self.untop(p)

    def get_subtree(self, node, begin, end):
        p = self.top()
        try:
            r = p.get_subtree(node, begin, end)
        finally:
            self.untop(p)
        return r

    def clear_subtree(self, node):
        p = self.top()
        try:
            p.clear_subtree(node)
        finally:
            self.untop(p)


class SchemaNode(object):
    parent = None

    def __init__(self):
        self.transitions = {}
        # Plugins that transform this particular node
        self.value_plugins = PluginStack()
        # Plugins that transform this node or its subtree
        self.tree_plugins = PluginStack()

    def child(self, name):
        tr = self.transitions.get(name)
        if tr:
            return tr
        return self.transitions.get(wildcard, nullSchema)

    def require_child(self, name):
        s = self.transitions.get(name)
        if s:
            return s
        # Create a new child which is a deep copy of the wildcard transition
        s = SchemaNode()
        s.parent = self
        s.copy(self.transitions.get(wildcard, nullSchema))
        self.transitions[name] = s
        return s

    def copy(self, other):
        if not other:
            return
        self.value_plugins.copy(other.value_plugins)
        self.tree_plugins.copy(other.tree_plugins)
        for name in other.transitions:
            if name != wildcard:
                self.require_child(name).copy(other.transitions[name])
        if wildcard in other.transitions:
            self.require_child(wildcard).copy(other.transitions[wildcard])

    def dump(self):
        s = {}
        for n in self.transitions:
            s[n] = self.transitions[n].dump()
        s['<value>'] = ','.join(str(x.plugin_id) for x in self.value_plugins.all)
        s['<tree>'] = ','.join(str(x.plugin_id) for x in self.tree_plugins.all)
        return s


#############################################
# Create the root document for the database #
#############################################

nullSchema = SchemaNode()
rootSchema = SchemaNode()
root = Doc(("d",), None, rootSchema)


class Wildcard(object):
    def __repr__(self):
        return "<?>"


wildcard = Wildcard()


##########
# Plugin #
##########

class Plugin(object):
    """
    Base class that defines the interface for plugins, which are created as
    subclasses. A plugin maps logical operations on a document (e.g., get, set,
    and clear operations) to physical operations on the representation of
    documents.
    The Index plugin provides an example illustrating the power and flexibility
    of plugins.
    """
    plugin_count = 0

    def _define_schema_path(self, path, start=rootSchema):
        s = start
        for i, n in enumerate(path):
            if n == wildcard:
                s.require_child(n)  # Make sure there is a wildcard entry
                for sn in s.transitions:
                    for end in self._define_schema_path(path[i + 1:], s.transitions[sn]):
                        yield end
                return
            s = s.require_child(n)
        yield s

    def _define_schema_star(self, start=None):
        if not start:
            yield nullSchema
            start = rootSchema
        yield start
        for n in start.transitions:
            for x in self._define_schema_star(start.transitions[n]):
                yield x

    def register(self, spec):
        self.plugin_id = Plugin.plugin_count
        Plugin.plugin_count += 1
        if spec == "*":
            sn = self._define_schema_star()
        else:
            sn = self._define_schema_path([{"?": wildcard}.get(s, s) for s in spec[1:]])
        for s in sn:
            s.value_plugins.add(self)
            t = s
            while t:
                t.tree_plugins.add(self)
                t = t.parent

    def get_value(self, node):
        return node._schema.value_plugins.get_value(node)

    def set_value(self, node, value):
        node._schema.value_plugins.set_value(node, value)

    def get_subtree(self, node, begin, end):
        return node._schema.tree_plugins.get_subtree(node, begin, end)

    def clear_subtree(self, node):
        node._schema.tree_plugins.clear_subtree(node)


class CorePlugin(Plugin):
    """
    Provides the default mapping of documents to key-value pairs.
    """

    def __init__(self):
        self.register("*")

    def get_value(self, node):
        return thread_local.tr[node.get_key()]

    def set_value(self, node, value):
        if isinstance(value, str):
            value = value.encode()

        if value is None:
            del thread_local.tr[node.get_key()]
        else:
            thread_local.tr[node.get_key()] = value

    def get_subtree(self, node, begin, end):
        rng = fdb.tuple.range(node._path)
        if begin is None:
            b = node.get_key()
        else:
            b = fdb.tuple.pack(node._path + (begin,))
        if end is None:
            e = rng.stop
        else:
            e = fdb.tuple.pack(node._path + (end,))
        return ((fdb.tuple.unpack(k), v) for (k, v) in thread_local.tr[b: e])

    def clear_subtree(self, node):
        del thread_local.tr[node.get_key(): fdb.tuple.range(node._path).stop]


CorePlugin()


######################
# ExtendedValueTypes #
######################

class ExtendedValueTypes(Plugin):
    """
    Encodes various values to strings using the FoundationDB tuple layer.
    Supports bytes strings, unicode strings, 64-bit signed integers, and null
    values.
    This is intended as a simple plugin illustrating an approach to
    serialization. As written, it is not compatible with the Index plugins.
    """

    def __init__(self):
        self.register("*")

    def get_value(self, node):
        return fdb.tuple.unpack(node.get_value())[0]

    def set_value(self, node, value):
        if isinstance(value, str):
            value = value.encode()

        node.set_value(fdb.tuple.pack((value,)))

    def get_subtree(self, node, begin, end):
        return ((path, fdb.tuple.unpack(v)[0]) for (path, v) in
                node._schema.tree_plugins.get_subtree(node, begin, end))


#########
# Index #
#########

class Index(Plugin):
    """
    Base class used by index plugins.
    A index provides a way to efficiently retrieve documents based on their
    values, which may occur at various locations with their hierarchical
    structure. For example, a web application with user accounts may want to
    retrieve all user documents containing a login subdocument having the value
    "expired". SimpleDoc employs FoundationDB's transactions to *guarantee* that
    indexes will stay in sync with the corresponding data.
    Indexes are stored in a special document off the root document.
    """

    def __init__(self, docPath, keyPath):
        docPath = ["d"] + docPath.split(".")
        if keyPath:
            keyPath = keyPath.split(".")
        else:
            keyPath = []
        self.docPath = tuple(docPath)
        self.keyPath = tuple(keyPath)
        self.dkPath = tuple(docPath + keyPath)
        self.index_keys = tuple(i for i, k in enumerate(docPath) if k == '?')
        self.key_keys = tuple(i + len(docPath) for i, k in enumerate(keyPath) if k == '?')
        self.register(self.dkPath)
        self.index_doc = root.index[str(self.plugin_id)]

    def set_value(self, node, value):
        self.update_index_if_required(node, value)
        node.set_value(value)

    def clear_subtree(self, node):
        depth = len(node._path)

        # Identify any wildcards in self.dkPath that haven't been filled in by node._path
        wild = [w for w in self.index_keys + self.key_keys if w >= depth]

        if not wild:
            # A specific document's index entry is removed
            affected = [node.get_descendant(self.dkPath[depth:])]
        elif len(wild) == len(self.index_keys + self.key_keys):
            # Absolutely everything in the index is removed!
            self.index_doc.clear_all()
            affected = []
        else:
            start = depth
            affected = [node]
            for w in wild:
                def getDescendants(nodes, subpath):
                    for n in nodes:
                        for c in n.get_descendant(subpath).get_children():
                            yield c

                affected = getDescendants(affected, self.dkPath[start:w])
                start = w + 1
            affected = (n.get_descendant(self.dkPath[start:]) for n in affected)

        # Remove the given items from the index
        for n in affected:
            self.update_index_if_required(n, None)

        # ..and actually do the requested clear
        node.clear_all()

    def update_index_if_required(self, node, value):
        oldv = node.get_value()
        if oldv == value: return

        path = [node._path[i] for i in self.key_keys + self.index_keys]
        self.update_index(path, oldv, value)

    def update_index(self, docKey, oldValue, newValue):
        pass


################
# OrderedIndex #
################

class OrderedIndex(Index):
    """
    Provides an ordered index on specified values within a document.
    The index is specified using two parameters: docKey and keyPath. Both
    parameters take formatted strings that use a simple pattern language
    to represent paths within a document. Patterns have the form:
        "node1.node2.node3. ..."
    where each "node" is either:
        1) a string to be matched against keys or values in the document, or
        2) the wildcard "?", which will match any string.
    The docKey pattern represents paths beginning from root. It selects the
    documents to be indexed.
    The keyPath pattern represents paths beginning from the docKey path. It
    selects the values on which the index is created.
    For example, if we have a document with data of the form:
        { "users": { "bob": { "eyecolor": "blue" }}}
    we could use:
        docKey = "users.?"
        keyPath = "eyecolor"
    to index individual users by their eyecolor. Note that it is not the string
    "eyecolor" but its corresponding value (e.g., "blue") that will be used for
    indexing. As a more complex example, we could use:
        docKey = users.?.inbox.?
        keyPath = cc.?.name
    to index messages in user inboxes by the name (e.g., "Alice Anderson") of
    others cc'ed on the message.
    An OrderedIndex is stored in order by value, allowing the use of
    range reads to retrieve ranges of values matching the index.
    """

    use_value = 1

    def update_index(self, docKey, oldValue, newValue):
        if oldValue != None:
            self.index_doc[oldValue].get_descendant(docKey).set_value(None)
        if newValue != None:
            self.index_doc[newValue].get_descendant(docKey).set_value("")

    def find_all(self, *value):
        path = list(self.docPath)
        index = self.index_doc
        start = len(index._path) + len(self.key_keys) + self.use_value
        for c, _ in index.get_descendant(value).get_descendant_values():
            for i, k in zip(self.index_keys, c._path[start:]):
                path[i] = k
            yield root.get_descendant(path[1:])

    def find_one(self, *value):
        index = self.index_doc
        start = len(index._path) + len(self.key_keys) + self.use_value
        for c, _ in index.get_descendant(value).get_descendant_values():
            path = list(self.docPath)
            for i, k in zip(self.index_keys, c._path[start:]):
                path[i] = k
            return root.get_descendant(path[1:])
        return None


# #############
# # HashIndex #
# #############
#
# class HashIndex(Index):
#     """
#     HashIndex is a basic index of the values of a document.
#     HashIndex is similar to OrderedIndex, but stores the hash of the
#     values in the index rather then the values themselves. This will usually
#     yield lower storage requrements and higher performance for simple equality
#     matches but does not support efficient scans over ranges of values.
#     """
#
#     def update_index(self, docKey, oldValue, newValue):
#         import md5
#         if oldValue != None:
#             self.index_doc[md5.new(str(oldValue)).hexdigest()].get_descendant(docKey).set_value(None)
#         if newValue != None:
#             self.index_doc[md5.new(str(newValue)).hexdigest()].get_descendant(docKey).set_value("")


############
# KeyIndex #
############

class KeyIndex(OrderedIndex):
    """
    Provides an index on specified keys within a document.
    KeyIndex is similar to OrderedIndex, but instead of indexing on specified
    values, it indexes on specified keys.
    As in OrderedIndex, the index is specified using docKey and keyPath
    parameters with the same pattern language. The keyPath parameter is used to
    directly match the key for indexing.
    For example, if we have a document with data of the form:
        {"users": {"bob": {"friends_with": {"john": ""},
                                           {"alice": ""},
                                           {"mary": ""}}}}
    we could use:
        docKey = "users.?"
        keyPath = "friends_with.?"
    to index users by their friends.
    """
    use_value = 0

    def update_index_if_required(self, node, value):
        # Does node._path match self.dkPath (including wildcards?)
        if len(self.dkPath) != len(node._path):
            return
        for i in range(len(self.dkPath)):
            if not (self.dkPath[i] == '?' or self.dkPath[i] == node._path[i]):
                return

        path = [node._path[i] for i in self.key_keys + self.index_keys]

        if value != None:
            self.index_doc.get_descendant(path).set_value("")
        else:
            self.index_doc.get_descendant(path).set_value(None)


###########################
# SimpleDoc Example Usage #
###########################

# Illustrates the following SimpleDoc capabilities:

#  - Creation of indexes using Index plugins
#  - Insertion and modification of data
#  - Query formulation using the indexes

# Using dot notation to describe paths in the root document, the example will
# use data of the form:

#  - pets.<pet_name>.species.<value>
#  - pets.<pet_name>.color.<value>.
#  - pets.<pet_name>.owners.<owner_name_N>.''

# Insert data
@transactional
def set_sample_data():
    root.clear_all()

    # Set the entire pets collection
    pets.set_value({
        'Fido': {
            'species': 'dog',
            'color': 'yellow',
            'owners': {
                'carol': ''
            },
        },
        'Fluffy': {
            'species': 'cat',
            'color': 'white',
            'owners': {
                'alice': ''
            },
        },
    })

    # Insert another pet
    pets['Buddy'] = {
        'species': 'cat',
        'color': 'black',
        'owners': {
            'alice': '',
            'bob': ''
        }
    }

    # Change a single value
    pets['Buddy'].species = 'dog'


@transactional
def set_vacation_status(owner, status):
    for pet in owner_index.find_all(owner):
        pet.vacation = status


# Queries formulated via index methods

@transactional
def find_all_dogs():
    return [pet.get_name() for pet in species_index.find_all('dog')]


@transactional
def pets_of_owner(owner):
    result = []
    for pet in owner_index.find_all(owner):
        result.append({'name': pet.get_name(),
                       'species': pet.species.get_value()})
    return result


@transactional
def pets_on_vacation():
    return [pet.get_name() for pet in vacation_index.find_all()]


# Print the entire SimpleDoc database

@transactional
def print_simpledoc():
    print("Database, including indexes:")
    print(root.get_json(pretty=True))


# Run example

def simpledoc_example():
    db = fdb.open()

    print("Insert initial data")
    set_sample_data(db)
    print_simpledoc(db)

    print("Query data")
    print("Find all dogs:", find_all_dogs(db))
    print("Find pets of alice:")
    for p in pets_of_owner(db, 'alice'):
        print("  ", p)

    print("Modify and query data")
    set_vacation_status(db, 'bob', 'bermuda')
    print("Pets with owners on vacation: ", pets_on_vacation(db))


if __name__ == "__main__":
    # Create indexes
    # Index documents matching pets.? on the *value* of pets.?.species
    # Supports queries to find all pets of a given species
    species_index = OrderedIndex("pets.?", "species")
    # Index documents matching pets.? on the *value* of pets.?.vacation
    # Supports queries to find all pets on vacation
    vacation_index = OrderedIndex("pets.?", "vacation")
    # Index documents matching pets.? on the *key* pets.?.owners.?
    # Supports queries to find all pets owned by a given owner
    owner_index = KeyIndex("pets.?", "owners.?")
    # Use pets collection within SimpleDoc database
    pets = root.pets
    simpledoc_example()
