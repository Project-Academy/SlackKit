//
//  Block+Desc.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

extension Block: CustomStringConvertible {
    public var description: String {
        switch type {
        case BlockType.divider.rawValue: 
            return "Divider"
        case BlockType.header.rawValue:
            return "Header(\"\(text!)\")"
        case BlockType.section.rawValue:
            return "Section(\"\(text!)\")"
        default: return "\(type) \(json)"
        }
    }
}
