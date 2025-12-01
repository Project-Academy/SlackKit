//
//  Text.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

extension Block {
    
    public struct Text: Codable, Equatable {
        
        //--------------------------------------
        // MARK: - VARIABLES -
        //--------------------------------------
        /**
         The formatting to use for this text object.
         **(Required)**
         
         - note: Can be one of `plain_text` or `mrkdwn`.
         */
        public let type: TextType
        /**
         The text for the block.
         **(Required)**
         
         This field accepts any of the standard [text formatting markup](https://docs.slack.dev/messaging/formatting-message-text) when type is `mrkdwn`.
         
         - note: The minimum length is 1 and maximum length is 3000 characters.
         */
        public var text: String
        /**
         Indicates whether emojis in a text field should be escaped into the colon emoji format.
         This field is only usable when type is `plain_text`.
         */
        public var emoji: Bool?
        /**
         Determines how a message is parsed.
         
         When set to `false` (as is default) URLs will be auto-converted into links, conversation names will be link-ified, and certain mentions will be [automatically parsed](https://docs.slack.dev/messaging/formatting-message-text#automatic-parsing).
         
         When set to `true`, Slack will continue to process all markdown formatting and [manual parsing strings](https://docs.slack.dev/messaging/formatting-message-text#advanced), but it won’t modify any plain-text content. For example, channel names will not be hyperlinked.
         
         - note: This field is only usable when type is `mrkdwn`.
         */
        public var verbatim: Bool?
        
        //--------------------------------------
        // MARK: - INITIALISERS -
        //--------------------------------------
        /// Markdown init
        public init(_ text: String, verbatim: Bool = false) {
            self.type = .markdown
            self.text = text
            if verbatim { self.verbatim = verbatim }
        }
        /// PlainText init
        public init(plain text: String, emoji: Bool? = true) {
            self.type = .plainText
            self.text = text
            self.emoji = emoji
        }
        
        //--------------------------------------
        // MARK: - JSON -
        //--------------------------------------
        var json: [String: Sendable] {
            var dict: [String: Sendable] = [
                "type": type.rawValue,
                "text": text
            ]
            if type == .plainText, let emoji {
                dict["emoji"] = emoji
            } else if type == .markdown, let verbatim {
                dict["verbatim"] = verbatim
            }
            return dict
        }
        
        //--------------------------------------
        // MARK: - TEXT TYPE ENUM -
        //--------------------------------------
        public enum TextType: String, Codable {
            case plainText = "plain_text"
            case markdown = "mrkdwn"
        }
    }
}

extension Block.Text: CustomStringConvertible {
    public var description: String { text }
}
