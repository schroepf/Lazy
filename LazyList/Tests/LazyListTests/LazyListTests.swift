@testable import LazyList
import XCTest

final class LazyListTests: XCTestCase {
    func test_subscript_withValueZeroAndEmptyList_shouldCallOnLoadAfter() {
        let expectation = XCTestExpectation(description: "Wait for onLoadAfter")

        let list = LazyList<String>(onLoadBefore: { index, onSuccess, onError in
            XCTFail("onLoadBefore was called but it shouldn't!")
        }, onLoadItem: { index, onSuccess, onError in
            XCTFail("onLoadItem was called but it shouldn't!")
        }, onLoadAfter: { index, onSuccess, onError in
            expectation.fulfill()
        })

        XCTAssertNil(list[0])

        wait(for: [expectation], timeout: Defaults.timeout)
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

        XCTAssertNil(list[0])   // TODO: Is this really what's expected? Shouldn't this return an empty result?
        wait(for: [expectation], timeout: Defaults.timeout)

        let result = list[0]
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isEmpty() ?? false)
    }

    static var allTests = [
        ("test_subscript_withValueZeroAndEmptyList_shouldCallOnLoadAfter", test_subscript_withValueZeroAndEmptyList_shouldCallOnLoadAfter),
    ]
}
