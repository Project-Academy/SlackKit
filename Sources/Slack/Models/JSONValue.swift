//
//  JSONValue.swift
//  SlackKit
//
//  A minimal, `Sendable` JSON tree.
//
//  Used to hold the shapes this kit doesn't model yet — an unrecognised
//  rich-text kind, an interactive element that isn't a button — so they survive
//  a decode/encode round trip **verbatim** instead of being flattened into a
//  sentinel. A message relayed through SlackKit should come out the other side
//  as the message that went in, including the parts we don't understand.
//

import Foundation

/// Any JSON value, preserved exactly.
public enum JSONValue: Codable, Equatable, Sendable {

    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let value = try? c.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? c.decode(Double.self) {
            self = .number(value)
        } else if let value = try? c.decode(String.self) {
            self = .string(value)
        } else if let value = try? c.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? c.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c,
                debugDescription: "Value is not representable as JSON"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case let .string(value): try c.encode(value)
        case let .number(value): try c.encode(value)
        case let .bool(value):   try c.encode(value)
        case let .object(value): try c.encode(value)
        case let .array(value):  try c.encode(value)
        case .null:              try c.encodeNil()
        }
    }

    //--------------------------------------
    // MARK: - ACCESSORS -
    //--------------------------------------

    public subscript(key: String) -> JSONValue? {
        guard case let .object(dict) = self else { return nil }
        return dict[key]
    }

    public var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    /// The object's fields, minus `keys` — used when a case has already
    /// consumed the fields it models and wants to keep only the remainder.
    package func objectDropping(_ keys: Set<String>) -> [String: JSONValue] {
        guard case let .object(dict) = self else { return [:] }
        return dict.filter { !keys.contains($0.key) }
    }
}
