//
//  Block.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

public struct Block: Codable {
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public let type: String
    /**
     A unique identifier for a block.
     
     If not specified, one will be generated.
     You can use this `block_id` when you receive an interaction payload to identify the source of the action.
     
     - note: Maximum length for this field is 255 characters.
     
     `block_id` should be unique for each message and each iteration of a message.
     If a message is updated, use a new `block_id`.
     */
    public var block_id: String?
    
    /**
     The text for the block, in the form of a ``Block.Text``.
     Usage depends on the type of block it is in; see below sections.
     
     ## Section Block
     Minimum length for the text in this field is 1 and maximum length is 3000 characters.
     This field is not _required_ if a valid array of `fields` objects is provided instead.
     
     ## Heading Block
     Maximum length for the text in this field is 150 characters.
     The text for the block, in the form of a `plain_text` ``Block.Text``.
     */
    public var text: Text?
    
    
    
    /**
     Used only for Section Blocks.
     
     Required if no `text` is provided. An array of text elements.
     Any text objects included with `fields` will be rendered in a compact format that allows for 2 columns of side-by-side text.
     - note: Maximum length for the text in each item is 2000 characters.
     - important: Maximum number of items is 10.
     
     [Click here for an example.](https://api.slack.com/tools/block-kit-builder?blocks=%5B%0A%09%7B%0A%09%09%22type%22%3A%20%22section%22%2C%0A%09%09%22text%22%3A%20%7B%0A%09%09%09%22text%22%3A%20%22A%20message%20*with%20some%20bold%20text*%20and%20_some%20italicized%20text_.%22%2C%0A%09%09%09%22type%22%3A%20%22mrkdwn%22%0A%09%09%7D%2C%0A%09%09%22fields%22%3A%20%5B%0A%09%09%09%7B%0A%09%09%09%09%22type%22%3A%20%22mrkdwn%22%2C%0A%09%09%09%09%22text%22%3A%20%22*Priority*%22%0A%09%09%09%7D%2C%0A%09%09%09%7B%0A%09%09%09%09%22type%22%3A%20%22mrkdwn%22%2C%0A%09%09%09%09%22text%22%3A%20%22*Type*%22%0A%09%09%09%7D%2C%0A%09%09%09%7B%0A%09%09%09%09%22type%22%3A%20%22plain_text%22%2C%0A%09%09%09%09%22text%22%3A%20%22High%22%0A%09%09%09%7D%2C%0A%09%09%09%7B%0A%09%09%09%09%22type%22%3A%20%22plain_text%22%2C%0A%09%09%09%09%22text%22%3A%20%22String%22%0A%09%09%09%7D%0A%09%09%5D%0A%09%7D%0A%5D)
     */
    public var fields: [Text]?
    
    //--------------------------------------
    // MARK: - BLOCK BUILDERS -
    //--------------------------------------
    /**
     Visually separates pieces of info inside of a message.
     
     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs
     */
    public static var divider: Block { .init(type: BlockType.divider.rawValue) }
    
    /**
     Displays a larger-sized text.
     
     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs
     
     - note: Maximum length for the text in this field is 150 characters.
     */
    public static func header(_ text: String, showEmojis: Bool = true) -> Block {
        let text = Text(plain: text, emoji: showEmojis)
        return .init(type: BlockType.header.rawValue, text: text)
    }
    /**
     Displays text, possibly alongside elements.
     
     ## Available in Surfaces
     - Modals
     - Messages
     - Home tabs
     
     ## Compatible Block Elements
     - Button
     - Checkboxes
     - Date picker
     - Image
     - Multi-select menus
     - Overflow menu
     - Radio button
     - Select menu
     - Time picker
     - Workflow buttons
     
     - note: Maximum length for the text in this field is 3000 characters.
     */
    public static func section(_ text: String, verbatim: Bool = false) -> Block {
        let text = Text(text, verbatim: verbatim)
        return .init(type: BlockType.section.rawValue, text: text)
    }
    
    //--------------------------------------
    // MARK: - JSON -
    //--------------------------------------
    public var json: [String : Sendable] {
        var dict: [String: Sendable] = ["type": type]
        
        if let text { dict["text"] = text.json }
        
        if let block_id { dict["block_id"] = block_id }
        return dict
    }
    
    //--------------------------------------
    // MARK: - HELPERS -
    //--------------------------------------
    private enum BlockType: String {
        case divider
        case header
        case section
    }
}
