
public struct BTreeMap<Key, Value> where Key : Comparable {

    public let order: Int
    public internal(set) var count = 0

    @usableFromInline
    internal var root = Node()

    @inlinable
    public init(order: Int = Self.defaultOrder) {
        if order <= 2 {
            fatalError("bad order")
        }
        self.order = order
    }

    @inlinable
    public var isEmpty: Bool {
        count == 0
    }

    @inlinable
    public func contains(_ key: Key) -> Bool {
        lookup(by: key).found
    }

    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            entry(of: key)?.value
        }
        set {
            if let value = newValue {
                update(value, for: key)
            } else {
                remove(for: key)
            }
        }
    }
}

public extension BTreeMap {
    @discardableResult
    mutating func update(_ value: Value, for key: Key) -> Value? {
        var (found, tracks) = lookup(by: key)
        var (node, index) = tracks.removeLast()
        if found {
            return node.entries[index].update(value)
        }

        node.entries.insert(.init(key: key, value: value), at: index)
        count += 1

        // rebalance the tree
        var parents = tracks.reversed().makeIterator()
        while node.entries.count > maxNodeEntriesCount {
            guard let (parent, index) = parents.next() else {
                root = Node(children: [node])
                root.splitChild(at: 0)
                break
            }
            parent.splitChild(at: index)
            node = parent
        }

        return nil
    }

    @discardableResult
    mutating func remove(for key: Key) -> Value? {
        var (found, tracks) = lookup(by: key)
        guard found else { return nil }
        var (node, index) = tracks.removeLast()

        // find successor then delete
        if !node.isLeaf {
            tracks.append((node, index + 1))
            var successor = node.children[index + 1]
            while !successor.isLeaf {
                tracks.append((successor, 0))
                successor = successor.children[0]
            }
            swap(&node.entries[index], &successor.entries[0])
            (node, index) = (successor, 0)
        }

        let entry = node.entries.remove(at: index)
        count -= 1

        // rebalance the tree
        var parents = tracks.reversed().makeIterator()
        while node.entries.count < minNodeEntriesCount {
            guard let (parent, index) = parents.next() else {
                if !node.isLeaf {
                    root = node.children[0]
                }
                break
            }
            let (left, right) = parent.brothers(at: index)
            if let left = left, left.entries.count > minNodeEntriesCount {
                parent.rotateChild(at: index, fromLeftBrother: true)
            } else if let right = right, right.entries.count > minNodeEntriesCount {
                parent.rotateChild(at: index, fromLeftBrother: false)
            } else {
                parent.mergeChild(at: index, withLeftBrother: left != nil)
            }
            node = parent
        }

        return entry.value
    }
}

// MARK: - Init

public extension BTreeMap {
    static var defaultOrder: Int { 12 }

    @inlinable
    init(order: Int = Self.defaultOrder, entries: [(Key, Value)]) {
        self.init(order: 12)
        entries.forEach { update($0.1, for: $0.0) }
    }
}

extension BTreeMap: ExpressibleByDictionaryLiteral {
    @inlinable
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(order: 12, entries: elements)
    }
}

// MARK: - Sequence

extension BTreeMap: Sequence {
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(root: root)
    }
}

public extension BTreeMap {

    struct Iterator: Swift.IteratorProtocol {

        public typealias Element = (key: Key, value: Value)

        var tracks: [Track] = []

        @inlinable
        init(root: Node) {
            buildTracks(for: root)
        }

        public mutating func next() -> Element? {
            guard !tracks.isEmpty else { return nil }
            let (node, index) = tracks.removeLast()
            let entry = node.entries[index]

            if index < node.entries.count - 1 {
                tracks.append((node, index + 1))
            }
            if !node.isLeaf {
                buildTracks(for: node.children[index + 1])
            }

            return (entry.key, entry.value)
        }

        @usableFromInline
        mutating func buildTracks(for node: Node) {
            var node = node
            while true {
                tracks.append((node, 0))
                if node.isLeaf {
                    break
                }
                node = node.children[0]
            }
        }
    }
}

// MARK: - Dump

extension BTreeMap {

    public func dump() -> String {
        var result = ""
        dump("┓", to: &result)
        dump(node: root, to: &result)
        return result
    }

    func dump(node: Node, prefix: String = "", to result: inout String) {
        let lastIndex = node.entries.count
        for index in 0...lastIndex {
            if !node.isLeaf {
                let isLastChild = index == lastIndex
                dump(prefix + (isLastChild ? "┗━━━━━━┓" : "┣━━━━━━┓"), to: &result)
                let nextPrefix = prefix + (isLastChild ? "       " : "┃      ")
                dump(node: node.children[index], prefix: nextPrefix, to: &result)
            }
            if index < lastIndex {
                let weld = node.isLeaf && index == lastIndex - 1 ? "┗" : "┣"
                dump("\(prefix)\(weld)━ \(node.entries[index].key)", to: &result)
            }
        }
    }

    @inlinable
    func dump(_ content: String, to result: inout String) {
        result += content
        result += "\n"
    }
}

// MARK: - Internal

extension BTreeMap {

    @usableFromInline
    typealias Track = (node: Node, index: Int)

    @usableFromInline
    func entry(of key: Key) -> Entry? {
        var (found, tracks) = lookup(by: key)
        guard found else { return nil }
        let (node, index) = tracks.removeLast()
        return node.entries[index]
    }

    @usableFromInline
    func lookup(by key: Key) -> (found: Bool, tracks: [Track]) {
        var node = root
        var tracks: [Track] = []

        while true {
            let (found, index) = node.find(by: key)
            tracks.append((node, index))
            if found {
                return (true, tracks)
            }
            if node.isLeaf {
                return (false, tracks)
            }
            node = node.children[index]
        }
    }

    @inlinable
    var maxNodeEntriesCount: Int {
        order - 1
    }

    @inlinable
    var minNodeEntriesCount: Int {
        (order + 1) / 2 - 1
    }
}

// MARK: - Node

extension BTreeMap {
    @usableFromInline
    internal final class Node {
        @usableFromInline
        var entries: [Entry] = []
        @usableFromInline
        var children: [Node] = []

        @inlinable
        init(entries: [Entry] = [], children: [Node] = []) {
            self.entries = entries
            self.children = children
        }
    }
}

extension BTreeMap.Node {
    @inlinable
    var isLeaf: Bool {
        children.isEmpty
    }

    func splitChild(at index: Int) {
        let child = children[index]
        let childIndex = child.entries.count >> 1
        let entry = child.entries[childIndex]

        let newNode = Self()
        newNode.entries = Array(child.entries[(childIndex + 1)...])
        newNode.children = child.isLeaf ? [] : Array(child.children[(childIndex + 1)...])

        child.entries = Array(child.entries[...(childIndex - 1)])
        child.children = child.isLeaf ? [] : Array(child.children[...childIndex])

        entries.insert(entry, at: index)
        children.insert(newNode, at: index + 1)
    }

    func brothers(at index: Int) -> (left: BTreeMap.Node?, right: BTreeMap.Node?) {
        func child(at index: Int) -> BTreeMap.Node? {
            guard (0..<children.count).contains(index) else { return nil }
            return children[index]
        }
        return (child(at: index - 1), child(at: index + 1))
    }

    func rotateChild(at index: Int, fromLeftBrother: Bool) {
        let (left, right) = fromLeftBrother
                ? (children[index - 1], children[index])
                : (children[index], children[index + 1])

        if fromLeftBrother {
            var entry = left.entries.removeLast()
            swap(&entries[index - 1], &entry)
            right.entries.insert(entry, at: 0)
            if !left.isLeaf {
                right.children.insert(left.children.removeLast(), at: 0)
            }
        } else {
            var entry = right.entries.removeFirst()
            swap(&entries[index], &entry)
            left.entries.append(entry)
            if !right.isLeaf {
                left.children.append(right.children.removeFirst())
            }
        }
    }

    func mergeChild(at index: Int, withLeftBrother: Bool) {
        let parentEntry = entries.remove(at: withLeftBrother ? index - 1 : index)
        let (left, right) = withLeftBrother
                ? (children[index - 1], children.remove(at: index))
                : (children[index], children.remove(at: index + 1))

        left.entries.append(contentsOf: [parentEntry] + right.entries)
        left.children.append(contentsOf: right.children)
    }

    func find(by key: Key) -> (found: Bool, index: Int) {
        var (start, end) = (0, entries.count)
        while start < end {
            let index = (start + end) / 2
            let middleKey = entries[index].key
            if key < middleKey {
                end = index
            } else if key > middleKey {
                start = index + 1
            } else {
                return (true, index)
            }
        }
        return (false, start)
    }
}

// MARK: - Entry

extension BTreeMap {
    @usableFromInline
    internal final class Entry {
        @usableFromInline
        let key: Key
        @usableFromInline
        var value: Value

        @inlinable
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }

        @inlinable
        @discardableResult
        func update(_ value: Value) -> Value {
            var value = value
            swap(&self.value, &value)
            return value
        }
    }
}
