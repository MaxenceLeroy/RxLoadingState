import RxRelay
import RxSwift
import RxSwiftExt

let delayBeforeSayingCommandIsFinishedInMs = 100

public enum NetworkPolicy {
    case networkAndCache
    case cacheAndNetwork
}

// TODO: [important, not ugent] [ClearCode] Convert to enum?
public struct ResponseWithLoadingState<T> where T: Equatable {
    public let isLoading: Bool
    public let data: T?
    public let error: Error?
}

extension ResponseWithLoadingState: Equatable where T: Equatable {
    public static func == (lhs: ResponseWithLoadingState<T>, rhs: ResponseWithLoadingState<T>) -> Bool {
        if let lhsError = lhs.error, let rhsError = rhs.error {
            return lhs.isLoading == rhs.isLoading && lhs.data == rhs.data && lhsError == rhsError
        } else {
            return lhs.isLoading == rhs.isLoading && lhs.data == rhs.data && lhs.error == nil && rhs.error == nil
        }
    }
}

private enum RefreshTriggerIntent {
    case beforeStartCommand
    case startCommand
}

// We need to make errors equatable for this to work
// https://stackoverflow.com/a/63624666
private func == (lhs: Error, rhs: Error) -> Bool {
    guard type(of: lhs) == type(of: rhs) else { return false }
    let error1 = lhs as NSError
    let error2 = rhs as NSError
    return error1.domain == error2.domain && error1.code == error2.code && "\(lhs)" == "\(rhs)"
}

private extension Equatable where Self: Error {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs as Error == rhs as Error
    }
}

private enum RefreshCommandStatus: Equatable {
    static func == (lhs: RefreshCommandStatus, rhs: RefreshCommandStatus) -> Bool {
        switch (lhs, rhs) {
        case (.commandStart, .commandStart):
            return true

        case (.commandSuccess, .commandSuccess):
            return true

        case let (.commandFailure(lhsError), .commandFailure(rhsError)):
            return lhsError == rhsError

        default:
            return false
        }
    }

    case commandStart
    case commandSuccess
    case commandFailure(error: Error)
}

public extension Observable {
    static func createWithLoadingState<T>(
        query: Observable<T>,
        refreshCommand: @escaping () -> Single<Void>,
        refreshTrigger: Observable<Void>,
        policy: NetworkPolicy,
        scheduler: SchedulerType = MainScheduler.instance
    ) -> Observable<ResponseWithLoadingState<T>> {
        // We can't create properly observables in a static function of observable, so we do the job in a different function
        createObservableWithLoadingState(query: query, refreshCommand: refreshCommand, refreshTrigger: refreshTrigger, policy: policy, scheduler: scheduler)
    }
}

private func createObservableWithLoadingState<T>(
    query: Observable<T>,
    refreshCommand: @escaping () -> Single<Void>,
    refreshTrigger: Observable<Void>,
    policy: NetworkPolicy,
    scheduler: SchedulerType
) -> Observable<ResponseWithLoadingState<T>> {
    let refreshCommandStatusSubject = BehaviorRelay<RefreshCommandStatus?>(value: nil)

    let refreshTriggerIntentObservable = refreshTrigger
        .filter { _ in
            if refreshCommandStatusSubject.value == .commandStart {
                return false
            } else {
                return true
            }
        }
        .flatMap { _ in Observable<RefreshTriggerIntent>.from([.beforeStartCommand, .startCommand]) }
        .share()

    let beforeStartDisposable = refreshTriggerIntentObservable
        .filter { refreshTriggerIntent in refreshTriggerIntent == .beforeStartCommand }
        .map { _ in .commandStart }
        .bind(to: refreshCommandStatusSubject)

    let startDisposable = refreshTriggerIntentObservable
        .filter { refreshTriggerIntent in refreshTriggerIntent == .startCommand }
        .flatMap { _ -> Single<RefreshCommandStatus> in
            refreshCommand()
                .map { _ in .commandSuccess }
                .catchError { error in Single.just(.commandFailure(error: error)) }
        }
        .delay(.milliseconds(delayBeforeSayingCommandIsFinishedInMs), scheduler: scheduler)
        .bind(to: refreshCommandStatusSubject)

    let refreshCommandStatusObservable = policy == .cacheAndNetwork ? refreshCommandStatusSubject.asObservable() : refreshCommandStatusSubject.filter { status in status != nil }

    return Observable
        .combineLatest(refreshCommandStatusObservable, query)
        .scan(ResponseWithLoadingState(isLoading: false, data: nil, error: nil)) { (acc, tuple) -> ResponseWithLoadingState<T> in
            let (refreshCommandStatus, data) = tuple
            
            if refreshCommandStatus == nil, policy == .cacheAndNetwork {
                return ResponseWithLoadingState(isLoading: false, data: data, error: nil)
            } else if refreshCommandStatus == .commandStart, acc.isLoading == false {
                let dataToUse = policy == .cacheAndNetwork ? data : acc.data
                return ResponseWithLoadingState(isLoading: true, data: dataToUse, error: nil)
            } else if refreshCommandStatus == .commandSuccess, acc.isLoading == true {
                return ResponseWithLoadingState(isLoading: false, data: data, error: nil)
            } else if acc.isLoading == true, case let .commandFailure(error) = refreshCommandStatus {
                let dataToUse = policy == .cacheAndNetwork ? data : acc.data
                return ResponseWithLoadingState(isLoading: false, data: dataToUse, error: error)
            } else {
                return acc
            }
        }
        .distinctUntilChanged()
        .do(onDispose: { () in
            beforeStartDisposable.dispose()
            startDisposable.dispose()
        })
}

public enum LoadingStatus {
    case loading, success, error
}

public extension Observable {
    func elements<T>() -> Observable<T?> where Element == ResponseWithLoadingState<T> {
        return map { response in response.data }
            .distinctUntilChanged()
    }

    func errors<T>() -> Observable<Error> where Element == ResponseWithLoadingState<T> {
        return map { response in response.error }
            .unwrap()
    }

    func loadingStatus<T>() -> Observable<LoadingStatus> where Element == ResponseWithLoadingState<T> {
        return map { response in
            if response.isLoading {
                return .loading
            } else if response.error != nil {
                return .error
            } else {
                return .success
            }
        }
        .distinctUntilChanged()
    }
}
