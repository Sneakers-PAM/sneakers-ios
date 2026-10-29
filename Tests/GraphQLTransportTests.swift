// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import Sneakers_PAM
import Testing

struct GraphQLTransportTests {
    private struct ErrorCase {
        let code: String
        let reason: String?
        let expected: VaultError
    }

    private func parse(_ status: Int, _ json: String) throws -> Data {
        try GraphQLResponse.parse(status: status, body: Data(json.utf8))
    }

    private func errorJSON(_ code: String, _ reason: String? = nil) -> String {
        let reasonPart = reason.map { #","reason":"\#($0)""# } ?? ""
        return #"{"data":null,"errors":[{"message":"x","extensions":{"code":"\#(code)"\#(reasonPart)}}]}"#
    }

    private func operation(_ variables: [String: GraphQLValue]) -> GraphQLOperation {
        GraphQLOperation(name: "Q", query: "query Q { x }", variables: variables)
    }

    // MARK: Request

    @Test func theRequestIsAJSONPostToGraphQLWithTheCookieAndTheCSRFToken() throws {
        let request = try HTTPGraphQLTransport.request(for: operation(["id": .string("s1")]), in: .fixture)

        #expect(request.url?.absoluteString == "https://one.example.org/graphql")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Cookie") == "sneakers_sid=abc123")
        #expect(request.value(forHTTPHeaderField: "X-CSRF-Token") == "tok")
        #expect(request.httpShouldHandleCookies == false)
    }

    @Test func theBodyCarriesTheQueryTheOperationNameAndTheVariables() throws {
        let sent = operation(["id": .string("s1"), "n": .int(5), "b": .bool(true)])
        let request = try HTTPGraphQLTransport.request(for: sent, in: .fixture)
        let body = try #require(request.httpBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let variables = try #require(object["variables"] as? [String: Any])

        #expect(object["query"] as? String == "query Q { x }")
        #expect(object["operationName"] as? String == "Q")
        #expect(variables["id"] as? String == "s1")
        #expect(variables["n"] as? Int == 5)
        #expect(variables["b"] as? Bool == true)
    }

    // MARK: Response

    @Test func aGoodAnswerReturnsTheDataObject() throws {
        let data = try parse(200, #"{"data":{"folders":[{"id":"f1"}]}}"#)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["folders"] != nil)
    }

    @Test func aMissingSessionEndsTheSession() {
        #expect(throws: VaultError.sessionEnded) { try parse(401, #"{"error":"no_session"}"#) }
    }

    @Test func aRefusedSecondFactorGateEndsTheSession() {
        #expect(throws: VaultError.sessionEnded) { try parse(403, #"{"error":"mfa_required"}"#) }
    }

    @Test func aGatewayThatCannotBeReachedIsUnreachable() {
        #expect(throws: VaultError.unreachable) { try parse(502, "") }
        #expect(throws: VaultError.unreachable) { try parse(503, "") }
    }

    @Test func eachGraphQLErrorCodeAndReasonMapsToItsMeaning() {
        var cases: [ErrorCase] = []
        cases.append(ErrorCase(code: "PERMISSION_DENIED", reason: "NO_ACCESS", expected: .noAccess))
        cases.append(ErrorCase(code: "PERMISSION_DENIED", reason: "CHECKOUT_NO_ACCESS", expected: .noAccess))
        cases.append(ErrorCase(code: "PERMISSION_DENIED", reason: "CHECKIN_NOT_HOLDER", expected: .notHolder))
        cases.append(ErrorCase(code: "FAILED_PRECONDITION", reason: "STEP_UP_REQUIRED", expected: .stepUpRequired))
        cases.append(ErrorCase(code: "FAILED_PRECONDITION", reason: "APPROVAL_REQUIRED", expected: .approvalRequired))
        cases.append(ErrorCase(code: "FAILED_PRECONDITION", reason: "RETIRED", expected: .retired))
        cases.append(ErrorCase(code: "FAILED_PRECONDITION", reason: "CHECKOUT_LEASE_HELD", expected: .leaseHeld))
        cases.append(ErrorCase(
            code: "FAILED_PRECONDITION",
            reason: "CHECKOUT_TYPE_DISABLED",
            expected: .checkoutNotAllowed
        ))
        cases.append(ErrorCase(code: "NOT_FOUND", reason: nil, expected: .notFound))
        cases.append(ErrorCase(code: "UNAUTHENTICATED", reason: nil, expected: .sessionEnded))
        cases.append(ErrorCase(code: "UNAVAILABLE", reason: nil, expected: .unreachable))
        cases.append(ErrorCase(code: "DEADLINE_EXCEEDED", reason: nil, expected: .unreachable))
        cases.append(ErrorCase(code: "INTERNAL", reason: nil, expected: .unexpected))
        for item in cases {
            #expect(throws: item.expected) { try parse(200, errorJSON(item.code, item.reason)) }
        }
    }

    @Test func anAnswerThatIsNotJSONIsUnexpected() {
        #expect(throws: VaultError.unexpected) { try parse(200, "<html>") }
    }

    @Test func everyFailureHasAMessageThatNeverEchoesServerText() {
        var all: [VaultError] = [.noAccess, .stepUpRequired, .approvalRequired, .retired, .leaseHeld, .notHolder]
        all += [.checkoutNotAllowed, .notFound, .sessionEnded, .unreachable, .unexpected]
        for failure in all {
            #expect(!failure.message.isEmpty)
            #expect(!failure.message.lowercased().contains("rpc error"))
        }
        #expect(VaultError.stepUpRequired.message == "Confirm it's you with a code to continue.")
        #expect(VaultError.unreachable.message == "Couldn't reach the server. Check your connection and try again.")
    }
}
