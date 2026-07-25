//
//  Block+Desc.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

extension Block: CustomStringConvertible {

    /**
     A debug summary.

     Every field is treated as optional, because from Slack's side they are: a
     section block carrying only `fields` and no `text` is legal (and
     documented as such on ``Block/text``). Force-unwrapping `text` here meant
     logging a perfectly valid message crashed the app.
     */
    public var description: String {
        switch type {
        case BlockType.divider.rawValue:
            return "Divider"
        case BlockType.header.rawValue:
            return "Header(\(quoted(text?.text)))"
        case BlockType.section.rawValue:
            if let text { return "Section(\(quoted(text.text)))" }
            if let fields, !fields.isEmpty {
                return "Section(fields: \(fields.map(\.text)))"
            }
            return "Section(empty)"
        default:
            let summary = plainText
            return summary.isEmpty ? type : "\(type)(\(quoted(summary)))"
        }
    }

    private func quoted(_ value: String?) -> String {
        guard let value else { return "—" }
        return "\"\(value)\""
    }
}
