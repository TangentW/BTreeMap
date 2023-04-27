import XCTest
@testable import BTreeMap

final class BTreeMapTests: XCTestCase {
    
    func testBTreeMap() throws {
        var tree = BTreeMap<Int, Int>(order: 3)

        let values = [35, 12, 77, 43, 12, 65, 99, 6, 77, 85, 52, 12]
        for value in values {
            tree[value] = value
        }

        XCTAssertEqual(tree[43], 43)
        XCTAssertEqual(tree[68], nil)

        XCTAssertEqual(tree.map { $0.key }, [6, 12, 35, 43, 52, 65, 77, 85, 99])
        tree[43] = nil
        XCTAssertEqual(tree.map { $0.key }, [6, 12, 35, 52, 65, 77, 85, 99])
    }
}
