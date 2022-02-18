//
//  File.swift
//
//
//  Created by Valentin Radu on 02/11/2021.
//

@testable import Firestarter
import XCTest

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
final class DispatcherTests: XCTestCase {
    @Dispatcher private var _dispatcher
    private var _service: TestService!
    private var _middleware: TestMiddleware!

    override func setUp() {
        _service = TestService()
        _middleware = TestMiddleware()

        _dispatcher.reset(history: true,
                          reducers: true,
                          middlewares: true)
        _dispatcher.register(reducer: _service)
        _dispatcher.register(middleware: _middleware)
    }

    func testRegister() async throws {
        let otherService = TestService()
        _dispatcher.register(reducer: otherService)
        try await _dispatcher.send(TestAction.resetPassword)

        XCTAssertEqual(otherService.actions.map(\.1), [.resetPassword])
    }

    func testPurgeHistory() async throws {
        _middleware.authState = .authenticated
        try await _dispatcher.send(
            TestAction
                .login(email: "", password: "")
                .then(other: .fetchAccount)
        )

        _dispatcher.reset(history: true)
        try await _dispatcher.send(TestAction.registerNewDevice(id: ""))

        // Even if all dependencies should be solved, `.registerNewDevice` won't be sent since we purged the history and would require an additional `.fetchAccount` to do so
        XCTAssertEqual(
            _service.actions.map(\.1.name),
            [
                .login,
                .fetchAccount,
                .postpone(.registerNewDevice, until: .fetchAccount)
            ]
        )
    }

    func testSendSuccess() async throws {
        try await _dispatcher.send(TestAction.resetPassword)
        XCTAssertEqual(_service.actions.map(\.1), [.resetPassword])
    }

    func testSendError() async throws {
        do {
            try await _dispatcher.send(TestAction.closeAccount)
            XCTFail()
        } catch {
            XCTAssertEqual(error as? TestError, TestError.accessDenied)
        }
    }
    
    func testEnvironment() async throws {
        let testDependency = TestDependency()
        _dispatcher.register(dependency: testDependency,
                             for: \.testDependency)
        try await _dispatcher.send(TestAction.resetPassword)
        XCTAssertTrue(_service.environment.testDependency === testDependency)
    }
}
