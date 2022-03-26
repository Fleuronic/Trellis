//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

/**
 The dispatch sends actions to all services and schedules their side effects.
  */
@MainActor
public class Dispatch {
    private var _services: [AnyHashable: Service] = [:]
    private var _tasks: [AnyHashable: Task<Void, Never>] = [:]

    func register<ID: Hashable>(_ id: ID, service: Service) {
        _services[id] = service
    }

    func unregister<ID: Hashable>(_ id: ID) {
        _services.removeValue(forKey: id)
    }

    func waitForAllTasks() async {
        for task in _tasks.values {
            _ = await task.result
        }
    }

    /// Sends an action to all the services in the pool.
    public func callAsFunction<A>(action: A) where A: Action {
        let key = AnyHashable(action)
        if let olderTask = _tasks[key] {
            olderTask.cancel()
        }
        let task = Task {
            var results: [ServiceResult] = []
            for service in _services.values {
                let result = await service.send(action: action)

                if result.hasSideEffects {
                    results.append(result)
                }
            }

            if !results.isEmpty {
                await withTaskGroup(of: Void.self) { taskGroup in
                    for result in results {
                        taskGroup.addTask {
                            await result()
                        }
                    }
                }
            }
        }
        _tasks[key] = task
    }
}

#if canImport(SwiftUI)
import SwiftUI

private struct DispatchKey: EnvironmentKey {
    @MainActor static var defaultValue: Dispatch = .init()
}

public extension EnvironmentValues {
    var dispatch: Dispatch {
        set { self[DispatchKey.self] = newValue }
        get { self[DispatchKey.self] }
    }
}

#endif
