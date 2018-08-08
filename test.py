import unittest

from node import Node, NodeProperty, PropertyKind, NodePropertyIndexes, WithNodeProperty

unittest.TestLoader.sortTestMethodsUsing = None


class TestingNodeBasicProperties(unittest.TestCase):
    def setUp(self):
        Node.schemas = {}
        self.user_node = Node('user', {
            'name': NodeProperty(PropertyKind.STRING),
            'email': NodeProperty(PropertyKind.STRING, [NodePropertyIndexes.UNIQUE]),
            'password': NodeProperty(PropertyKind.STRING)
        })
        self.db = self.user_node.db
        self.user_node.clear_subspace(self.db, self.user_node.directory)

    def test_1_set_node(self):
        uid = self.user_node.set(self.db, {
            'name': 'sif',
            'email': 'test@test.com',
            'password': 'super_strong'
        })

        self.assertEqual(self.user_node.get_all(self.db, uid),
                         {b'email': b'test@test.com', b'name': b'sif', b'password': b'super_strong',
                          b'uid': b'\x01\x00\x00\x00\x00\x00\x00\x00'})
        self.assertEqual(self.user_node.get_vertex_value(self.db, uid, 'name'), b'sif')
        self.assertEqual(self.user_node.get_by(self.db, 'name', 'sif'), [
            {b'email': b'test@test.com', b'name': b'sif', b'password': b'super_strong',
             b'uid': b'\x01\x00\x00\x00\x00\x00\x00\x00'}])

    def test_2_unique_index(self):
        self.user_node.set(self.db, {
            'name': 'sif',
            'email': 'test@test.com',
            'password': 'super_strong'
        })

        uid2 = self.user_node.set(self.db, {
            'name': 'sif2',
            'email': 'test@test.com',
            'password': 'super_strong2222'
        })

        self.assertEqual(uid2, None)  # return None since email already exist
        self.assertEqual(self.user_node.get_by(self.db, 'name', 'sif2'), None)

    def test_3_auto_increment(self):
        self.user_node.set(self.db, {
            'name': 'sif',
            'email': 'test@test.com',
            'password': 'super_strong'
        })

        uid3 = self.user_node.set(self.db, {
            'name': 'sif2',
            'email': 'test@test.comm',
            'password': '123456'
        })

        self.assertEqual(self.user_node.get_all(self.db, uid3),
                         {b'email': b'test@test.comm', b'name': b'sif2', b'password': b'123456',
                          b'uid': b'\x02\x00\x00\x00\x00\x00\x00\x00'})
        self.assertEqual(self.user_node.get_vertex_value(self.db, uid3, 'name'), b'sif2')
        self.assertEqual(self.user_node.get_by(self.db, 'name', 'sif2'), [
            {b'email': b'test@test.comm', b'name': b'sif2', b'password': b'123456',
             b'uid': b'\x02\x00\x00\x00\x00\x00\x00\x00'}])


class TestingNodeRelationships(unittest.TestCase):
    def setUp(self):
        Node.schemas = {}
        self.user_node = Node('user', {
            'name': NodeProperty(PropertyKind.STRING),
            'email': NodeProperty(PropertyKind.STRING, [NodePropertyIndexes.UNIQUE]),
            'password': NodeProperty(PropertyKind.STRING)
        })
        self.msg_node = Node('msg', {
            'from_user': WithNodeProperty(PropertyKind.NODE, 'user'),
            'to_user': WithNodeProperty(PropertyKind.NODE, 'user'),
            'value': NodeProperty(PropertyKind.STRING)
        })
        self.db = self.user_node.db
        self.user_node.clear_subspace(self.db, self.user_node.directory)
        self.msg_node.clear_subspace(self.db, self.msg_node.directory)

    def test_node_with_childs(self):
        uid = self.user_node.set(self.db, {
            'name': 'sif',
            'email': 'test@test.com',
            'password': 'super_strong'
        })
        uid3 = self.user_node.set(self.db, {
            'name': 'sif2',
            'email': 'test@test.comm',
            'password': '123456'
        })
        msg_uid = self.msg_node.set(self.db, {
            'from_user': uid,
            'to_user': uid3,
            'value': 'testing a message from nodes'
        })

        self.assertEqual(self.msg_node.get_all(self.db, msg_uid), {b'from_user': b'\x01\x00\x00\x00\x00\x00\x00\x00',
                                                                   b'to_user': b'\x02\x00\x00\x00\x00\x00\x00\x00',
                                                                   b'uid': b'\x03\x00\x00\x00\x00\x00\x00\x00',
                                                                   b'value': b'testing a message from nodes'})
        self.assertEqual(self.msg_node.get_vertex_value(self.db, msg_uid, 'value'), b'testing a message from nodes')
        self.assertEqual(self.msg_node.get_by(self.db, 'value', 'testing a message from nodes'), [
            {b'from_user': b'\x01\x00\x00\x00\x00\x00\x00\x00', b'to_user': b'\x02\x00\x00\x00\x00\x00\x00\x00',
             b'uid': b'\x03\x00\x00\x00\x00\x00\x00\x00', b'value': b'testing a message from nodes'}])

        a = {
            'uid': None,
            'value': None,
            'to_user': {
                'name': None,
                'password': None
            },
            'from_user': {
                'name': None,
                'email': None
            }
        }

        self.assertEqual(self.msg_node.get(self.db, msg_uid, a),
                         {'uid': b'\x03\x00\x00\x00\x00\x00\x00\x00', 'value': b'testing a message from nodes',
                          'to_user': {'name': b'sif2', 'password': b'123456'},
                          'from_user': {'name': b'sif', 'email': b'test@test.com'}})


if __name__ == '__main__':
    unittest.main()
