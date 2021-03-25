import RxSwift
import RxTest
import XCTest
@testable import RxLoadingState

class ObservableCreateWithLoadingStateTests: XCTestCase {
    enum TestError: Error {
        case baseError
    }

    func testNetworkAndCache() {
        // Given
        let scheduler = TestScheduler(initialClock: 0)
        let query = scheduler.createHotObservable([
            .next(250, "oldData"),
            .next(350, "newData")
        ])

        let refreshCommand = { () in Single.just(()).delay(.seconds(50), scheduler: scheduler) }

        let refreshTrigger = scheduler.createHotObservable([
            .next(300, ())
        ])

        // When
        let res = scheduler.start {
            Observable<ResponseWithLoadingState<String>>.createWithLoadingState(
                query: query.asObservable(),
                refreshCommand: refreshCommand,
                refreshTrigger: refreshTrigger.asObservable(),
                policy: .networkAndCache,
                scheduler: scheduler
            )
        }

        // Then
        let expectedAnswer = [
            ResponseWithLoadingState(isLoading: true, data: nil, error: nil),
            ResponseWithLoadingState(isLoading: false, data: "newData", error: nil)
        ]

        XCTAssertRecordedElements(res.events, expectedAnswer)
    }

    func testNetworkAndCacheDoubleTrigger() {
        // Given
        let scheduler = TestScheduler(initialClock: 0)

        let query = scheduler.createHotObservable([
            .next(250, "oldData"),
            .next(350, "newData1"),
            .next(650, "newData2")
        ])

        let refreshCommand = { () in Single.just(()).delay(.seconds(50), scheduler: scheduler) }

        let refreshTrigger = scheduler.createHotObservable([
            .next(300, ()),
            .next(600, ())
        ])

        // When
        let res = scheduler.start {
            Observable<ResponseWithLoadingState<String>>.createWithLoadingState(
                query: query.asObservable(),
                refreshCommand: refreshCommand,
                refreshTrigger: refreshTrigger.asObservable(),
                policy: .networkAndCache,
                scheduler: scheduler
            )
        }

        // Then
        let expectedAnswer = [
            ResponseWithLoadingState(isLoading: true, data: nil, error: nil),
            ResponseWithLoadingState(isLoading: false, data: "newData1", error: nil),
            ResponseWithLoadingState(isLoading: true, data: "newData1", error: nil),
            ResponseWithLoadingState(isLoading: false, data: "newData2", error: nil)
        ]

        XCTAssertRecordedElements(res.events, expectedAnswer)
    }

    func testCacheAndNetwork() {
        // Given
        let scheduler = TestScheduler(initialClock: 0)
        let query = scheduler.createHotObservable([
            .next(250, "oldData"),
            .next(350, "newData")
        ])

        let refreshCommand = { () in Single.just(()).delay(.seconds(50), scheduler: scheduler) }

        let refreshTrigger = scheduler.createHotObservable([
            .next(300, ())
        ])

        // When
        let res = scheduler.start {
            Observable<ResponseWithLoadingState<String>>.createWithLoadingState(
                query: query.asObservable(),
                refreshCommand: refreshCommand,
                refreshTrigger: refreshTrigger.asObservable(),
                policy: .cacheAndNetwork,
                scheduler: scheduler
            )
        }

        // Then
        let expectedAnswer = [
            ResponseWithLoadingState(isLoading: false, data: "oldData", error: nil),
            ResponseWithLoadingState(isLoading: true, data: "oldData", error: nil),
            ResponseWithLoadingState(isLoading: false, data: "newData", error: nil)
        ]

        XCTAssertRecordedElements(res.events, expectedAnswer)
    }

    func testCacheAndNetworkDoubleTrigger() {
        // Given
        let scheduler = TestScheduler(initialClock: 0)

        let query = scheduler.createHotObservable([
            .next(250, "oldData"),
            .next(350, "newData1"),
            .next(650, "newData2")
        ])

        let refreshCommand = { () in Single.just(()).delay(.seconds(50), scheduler: scheduler) }

        let refreshTrigger = scheduler.createHotObservable([
            .next(300, ()),
            .next(600, ())
        ])

        // When
        let res = scheduler.start {
            Observable<ResponseWithLoadingState<String>>.createWithLoadingState(
                query: query.asObservable(),
                refreshCommand: refreshCommand,
                refreshTrigger: refreshTrigger.asObservable(),
                policy: .cacheAndNetwork,
                scheduler: scheduler
            )
        }

        // Then
        let expectedAnswer = [
            ResponseWithLoadingState(isLoading: false, data: "oldData", error: nil),
            ResponseWithLoadingState(isLoading: true, data: "oldData", error: nil),
            ResponseWithLoadingState(isLoading: false, data: "newData1", error: nil),
            ResponseWithLoadingState(isLoading: true, data: "newData1", error: nil),
            ResponseWithLoadingState(isLoading: false, data: "newData2", error: nil)
        ]

        XCTAssertRecordedElements(res.events, expectedAnswer)
    }

    func testNetworkAndCacheError() {
        // Given
        let scheduler = TestScheduler(initialClock: 0)

        let query = scheduler.createHotObservable([
            .next(250, "oldData")
        ])

        let refreshCommand = { () in Single<Void>.error(TestError.baseError).delay(.seconds(50), scheduler: scheduler) }

        let refreshTrigger = scheduler.createHotObservable([
            .next(300, ())
        ])

        // When
        let res = scheduler.start {
            Observable<ResponseWithLoadingState<String>>.createWithLoadingState(
                query: query.asObservable(),
                refreshCommand: refreshCommand,
                refreshTrigger: refreshTrigger.asObservable(),
                policy: .networkAndCache,
                scheduler: scheduler
            )
        }

        // Then
        let expectedAnswer = [
            ResponseWithLoadingState<String>(isLoading: true, data: nil, error: nil),
            ResponseWithLoadingState<String>(isLoading: false, data: nil, error: TestError.baseError)
        ]

        XCTAssertRecordedElements(res.events, expectedAnswer)
    }

    func testCacheAndNetworkError() {
        // Given
        let scheduler = TestScheduler(initialClock: 0)

        let query = scheduler.createHotObservable([
            .next(250, "oldData")
        ])

        let refreshCommand = { () in Single<Void>.error(TestError.baseError).delay(.seconds(50), scheduler: scheduler) }

        let refreshTrigger = scheduler.createHotObservable([
            .next(300, ())
        ])

        // When
        let res = scheduler.start {
            Observable<ResponseWithLoadingState<String>>.createWithLoadingState(
                query: query.asObservable(),
                refreshCommand: refreshCommand,
                refreshTrigger: refreshTrigger.asObservable(),
                policy: .cacheAndNetwork,
                scheduler: scheduler
            )
        }

        // Then
        let expectedAnswer = [
            ResponseWithLoadingState(isLoading: false, data: "oldData", error: nil),
            ResponseWithLoadingState(isLoading: true, data: "oldData", error: nil),
            ResponseWithLoadingState(isLoading: false, data: "oldData", error: TestError.baseError)
        ]

        XCTAssertRecordedElements(res.events, expectedAnswer)
    }

    func testNetworkAndCacheRetryAfterError() {
        // Given
        let scheduler = TestScheduler(initialClock: 0)

        let query = scheduler.createHotObservable([
            .next(250, "oldData"),
            .next(650, "newData")
        ])

        var hasFailedOnce = false

        let refreshCommand = { () -> Single<Void> in
            if hasFailedOnce {
                return Single.just(()).delay(.seconds(50), scheduler: scheduler)
            } else {
                hasFailedOnce = true
                return Single<Void>.error(TestError.baseError).delay(.seconds(50), scheduler: scheduler)
            }
        }

        let refreshTrigger = scheduler.createHotObservable([
            .next(300, ()),
            .next(600, ())
        ])

        // When
        let res = scheduler.start {
            Observable<ResponseWithLoadingState<String>>.createWithLoadingState(
                query: query.asObservable(),
                refreshCommand: refreshCommand,
                refreshTrigger: refreshTrigger.asObservable(),
                policy: .networkAndCache,
                scheduler: scheduler
            )
        }

        // Then
        let expectedAnswer = [
            ResponseWithLoadingState<String>(isLoading: true, data: nil, error: nil),
            ResponseWithLoadingState<String>(isLoading: false, data: nil, error: TestError.baseError),
            ResponseWithLoadingState<String>(isLoading: true, data: nil, error: nil),
            ResponseWithLoadingState(isLoading: false, data: "newData", error: nil)
        ]

        XCTAssertRecordedElements(res.events, expectedAnswer)
    }

    func testCacheAndNetworkRetryAfterError() {
        // Given
        let scheduler = TestScheduler(initialClock: 0)

        let query = scheduler.createHotObservable([
            .next(250, "oldData"),
            .next(650, "newData")
        ])

        var hasFailedOnce = false

        let refreshCommand = { () -> Single<Void> in
            if hasFailedOnce {
                return Single.just(()).delay(.seconds(50), scheduler: scheduler)
            } else {
                hasFailedOnce = true
                return Single<Void>.error(TestError.baseError).delay(.seconds(50), scheduler: scheduler)
            }
        }

        let refreshTrigger = scheduler.createHotObservable([
            .next(300, ()),
            .next(600, ())
        ])

        // When
        let res = scheduler.start {
            Observable<ResponseWithLoadingState<String>>.createWithLoadingState(
                query: query.asObservable(),
                refreshCommand: refreshCommand,
                refreshTrigger: refreshTrigger.asObservable(),
                policy: .cacheAndNetwork,
                scheduler: scheduler
            )
        }

        // Then
        let expectedAnswer = [
            ResponseWithLoadingState<String>(isLoading: false, data: "oldData", error: nil),
            ResponseWithLoadingState<String>(isLoading: true, data: "oldData", error: nil),
            ResponseWithLoadingState<String>(isLoading: false, data: "oldData", error: TestError.baseError),
            ResponseWithLoadingState<String>(isLoading: true, data: "oldData", error: nil),
            ResponseWithLoadingState(isLoading: false, data: "newData", error: nil)
        ]

        XCTAssertRecordedElements(res.events, expectedAnswer)
    }
}
