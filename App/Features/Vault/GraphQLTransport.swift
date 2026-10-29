// Copyright 2026 The Sneakers-PAM Authors
// SPDX-License-Identifier: Apache-2.0

import Foundation

nonisolated enum GraphQLValue: Equatable, Encodable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case list([GraphQLValue])
    case object([String: GraphQLValue])

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .list(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}

nonisolated struct GraphQLOperation: Equatable, Sendable {
    let name: String
    let query: String
    var variables: [String: GraphQLValue] = [:]
}

/// Sends one GraphQL operation and hands back the `data` object. The real one calls the network.
nonisolated protocol GraphQLTransport: Sendable {
    func execute(_ operation: GraphQLOperation, in context: ServerContext) async throws -> Data
}

/// Reads the gateway's answer: the HTTP status first, then GraphQL errors by their stable code and reason.
nonisolated enum GraphQLResponse {
    static func parse(status: Int, body: Data) throws -> Data {
        switch status {
        case 200:
            break
        case 401, 403:
            throw VaultError.sessionEnded
        case 502 ... 504:
            throw VaultError.unreachable
        default:
            throw VaultError.unexpected
        }
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw VaultError.unexpected
        }
        if let errors = object["errors"] as? [[String: Any]], let first = errors.first {
            let extensions = first["extensions"] as? [String: Any]
            let code = extensions?["code"] as? String ?? ""
            throw VaultError(code: code, reason: extensions?["reason"] as? String)
        }
        guard let data = object["data"], !(data is NSNull),
              let bytes = try? JSONSerialization.data(withJSONObject: data)
        else {
            throw VaultError.unexpected
        }
        return bytes
    }
}
