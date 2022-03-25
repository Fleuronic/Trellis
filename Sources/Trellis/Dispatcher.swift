//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

/**
 The dispatcher sends actions to all services and schedules their side effects.
  */
public actor Dispatcher {
    private var _services: [AnyHashable: Service] = [:]

    func register<ID: Hashable>(_ id: ID, service: Service) {
        _services[id] = service
    }

    func unregister<ID: Hashable>(_ id: ID) {
        _services.removeValue(forKey: id)
    }

    /// Sends an action to all the services in the pool.
    public func send<A>(action: A) async where A: Action {
        let resolvers = await withTaskGroup(of: ServiceResult.self) { taskGroup -> [ServiceResult] in
            for service in _services.values {
                taskGroup.addTask {
                    await service.send(action: action)
                }
            }

            var result: [ServiceResult] = []
            for await sideEffect in taskGroup {
                if sideEffect.hasSideEffects {
                    result.append(sideEffect)
                }
            }
            return result
        }

        if !resolvers.isEmpty {
            await withThrowingTaskGroup(of: Void.self) { taskGroup in
                for resolver in resolvers {
                    taskGroup.addTask {
                        await resolver.performSideEffects()
                    }
                }
            }
        }
    }
}
