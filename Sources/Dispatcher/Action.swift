//
//  File.swift
//
//
//  Created by Valentin Radu on 17/10/2021.
//

import Foundation

public protocol Action {
    associatedtype Name
    var name: Name { get }
}

public struct AnyAction {
    private let action: Any
    public init<A: Action>(_ action: A) {
        self.action = action
    }
}

public extension Action {
    func then(other: Self) -> ActionFlow<Self> {
        ActionFlow(actions: [self, other])
    }

    func and(other: Self.Name) -> ActionGroup<Self> {
        ActionGroup(self.name, other)
    }
}

public struct ActionFlow<A: Action> {
    fileprivate let actions: [A]
    public func then(_ other: Self) -> Self {
        ActionFlow(actions: self.actions + other.actions)
    }

    public func then(_ action: A) -> Self {
        ActionFlow(actions: self.actions + [action])
    }
}

public struct ActionGroup<A: Action> {
    fileprivate let names: [A.Name]

    public init(_ names: A.Name...) {
        self.names = names
    }

    public init(_ names: [A.Name]) {
        self.names = names
    }

    public func and(_ other: Self) -> Self {
        ActionGroup(self.names + other.names)
    }

    public func and(_ name: A.Name) -> Self {
        ActionGroup(self.names + [name])
    }
}

extension ActionGroup: Codable where A.Name: Codable {}
extension ActionFlow: Codable where A: Codable {}
