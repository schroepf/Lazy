@testable import LazyList
import XCTest

final class LazyListTests: XCTestCase {
    func test_subscript_withIndexZeroAndEmptyList_shouldCallOnLoadAfter() {
        let onLoadAfterExpectation = expectation(description: "onLoadAfter")

        let list = LazyList<String>(onLoadBefore: { index, onSuccess, onError in
            XCTFail("onLoadBefore was called but it shouldn't!")
        }, onLoadItem: { index, onSuccess, onError in
            XCTFail("onLoadItem was called but it shouldn't!")
        }, onLoadAfter: { index, onSuccess, onError in
            onLoadAfterExpectation.fulfill()
        })

        XCTAssertNil(list[0])
        waitForExpectations(timeout: Defaults.timeout, handler: nil)
    }

    func test_onSuccessCallback_withNoItemsAndEmptyList_shouldAddItemsToList() {
        let expectation = XCTestExpectation(description: "Wait for onLoadAfter")

        let list = LazyList<String>(onLoadBefore: { index, onSuccess, onError in
            XCTFail("onLoadBefore was called but it shouldn't!")
        }, onLoadItem: { index, onSuccess, onError in
            XCTFail("onLoadItem was called but it shouldn't!")
        }, onLoadAfter: { index, onSuccess, onError in
            onSuccess(nil)
            expectation.fulfill()
        })

        // items should contain only one entry: 'nil'
        let items = list.items
        XCTAssertEqual(items.count, 1, "Initially the LazyList ist supposed to contain one 'nil' item.")
        XCTAssertNil(items.first ?? nil)

        // subscript operator will also return nil, but will also trigger a load event
        XCTAssertNil(list[0], "Initially the LazyList ist supposed to contain one 'nil' item.")
        wait(for: [expectation], timeout: Defaults.timeout) // wait for the onLoadAfter callback to finish...

        guard let result = list[0] else {
            XCTFail("Unexpectedly found a 'nil' value instead of an empty result!")
            return
        }

        XCTAssertTrue(result.isEmpty(), "Result at index 0 is not empty!")
    }

    // TODO: after onLoadFinished with 'nil' result the list size should decrease by 1 (if called on an empty list it should change from [nil] to []
    // TODO: onLoadAfter is not called a second time after it called onSuccess with 'nil'
    // TODO: test call to onError from all 3 callbacks

    static var allTests = [
        ("test_subscript_withIndexZeroAndEmptyList_shouldCallOnLoadAfter", test_subscript_withIndexZeroAndEmptyList_shouldCallOnLoadAfter),
    ]
}
