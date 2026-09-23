import XCTest
@testable import Fabushi

@MainActor
private final class HostRecoveryStub: MahayanaHostRequesting {
    let result: Result<Any, Error>

    init(result: Result<Any, Error>) {
        self.result = result
    }

    func request(
        method: String,
        params: [String: Any]
    ) async throws -> MahayanaHostJSONResult {
        switch result {
        case .success(let value):
            return MahayanaHostJSONResult(value: value)
        case .failure(let error):
            throw error
        }
    }
}

final class LocalHostRecoveryTests: XCTestCase {
    @MainActor
    func testRecoverableHostFailureSettlesRequestThenServesNextGeneration() async throws {
        let failed = HostRecoveryStub(
            result: .failure(MahayanaHostRuntime.HostError.invalidResponse)
        )
        let recovered = HostRecoveryStub(result: .success("recovered"))
        var factoryCalls = 0
        let supervisor = MahayanaLocalHostSupervisor(
            host: failed,
            factory: {
                factoryCalls += 1
                return recovered
            }
        )
        let coordinator = MahayanaCoordinator(hostSupervisor: supervisor)

        do {
            _ = try await coordinator.request(method: "first")
            XCTFail("failed host request must settle as an error and must not replay")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("无效响应"))
        }

        XCTAssertEqual(factoryCalls, 1)
        XCTAssertEqual(coordinator.hostGeneration, 2)

        let next = try await coordinator.request(method: "second")
        XCTAssertEqual(next.value as? String, "recovered")
        XCTAssertEqual(factoryCalls, 1)
    }

    @MainActor
    func testStaleHostFailureCannotReplaceNewerGeneration() throws {
        let first = HostRecoveryStub(result: .success("first"))
        let second = HostRecoveryStub(result: .success("second"))
        var factoryCalls = 0
        let supervisor = MahayanaLocalHostSupervisor(
            host: first,
            factory: {
                factoryCalls += 1
                return second
            }
        )
        let observed = supervisor.generation

        XCTAssertTrue(try supervisor.recoverAfterFailure(observedGeneration: observed))
        XCTAssertFalse(try supervisor.recoverAfterFailure(observedGeneration: observed))
        XCTAssertEqual(supervisor.generation, 2)
        XCTAssertEqual(factoryCalls, 1)
    }

    @MainActor
    func testBusinessRequestFailureDoesNotRestartHost() async {
        let failed = HostRecoveryStub(
            result: .failure(MahayanaHostRuntime.HostError.requestFailed("business-rule"))
        )
        var factoryCalls = 0
        let supervisor = MahayanaLocalHostSupervisor(
            host: failed,
            factory: {
                factoryCalls += 1
                return HostRecoveryStub(result: .success("unexpected"))
            }
        )
        let coordinator = MahayanaCoordinator(hostSupervisor: supervisor)

        do {
            _ = try await coordinator.request(method: "write")
            XCTFail("business error should surface")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("business-rule"))
        }

        XCTAssertEqual(coordinator.hostGeneration, 1)
        XCTAssertEqual(factoryCalls, 0)
    }
}
