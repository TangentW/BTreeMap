# BTreeMap

 An in-memory B-Tree implementation for Swift.
 
 This project is intended for learning purposes.

# Usage

```Swift
var tree = BTreeMap<Int, Int>(order: 3)

let values = [35, 12, 77, 43, 12, 65, 99, 6, 77, 85, 52, 12]
for value in values {
    // insert or update key-value entry
    tree[value] = value
}

assert(tree[99] == 99)
assert(tree[68] == nil)

// iterate over the tree in order
let sortedList = tree.map { $0.key }
assert(sortedList == [6, 12, 35, 43, 52, 65, 77, 85, 99])

// remove key-value entry
tree[43] = nil

// ┓
// ┣━━━━━━┓
// ┃      ┣━━━━━━┓
// ┃      ┃      ┣━ 6
// ┃      ┃      ┗━ 12
// ┃      ┣━ 35
// ┃      ┗━━━━━━┓
// ┃             ┗━ 52
// ┣━ 65
// ┗━━━━━━┓
//        ┣━━━━━━┓
//        ┃      ┗━ 77
//        ┣━ 85
//        ┗━━━━━━┓
//               ┗━ 99
print(tree.dump()) 
```
