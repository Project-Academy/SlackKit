//
//  Chat.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

private enum Chat: String, Endpoints {
    typealias API = Slack
    static let base = API.baseURL
    
    case postMessage
    case update
    case delete
    
    var path: URL { Chat.base.appending(component: "chat.\(rawValue)") }
}

extension Message {
    
    @discardableResult
    public func send(from sender: Author? = nil, to channel: String) async throws -> MessageResponse {
        
        let author = sender != nil
        ? sender
        : await Slack.defaultAuthor
        
        let resp = try await Chat.postMessage.POST
            .message(self)
            .from(author)
            .to(channel)
            .response()
        
        guard let chatResp = try? resp.asType(ChatResponse.self),
              let response = MessageResponse(chatResp)
        else { throw SlackError.Chat(resp.JSON["error"] as? String)  }
        return response
    }
    
    @discardableResult
    public static func update(messageAt ts: String, in channel: String, with newMessage: Message) async throws -> MessageResponse {
        
        let resp = try await Chat.update.POST
            .messageAt(ts, in: channel)
            .message(newMessage)
            .response()
        
        guard let chatResp = try? resp.asType(ChatResponse.self),
              let response = MessageResponse(chatResp)
        else { throw SlackError.Chat(resp.JSON)  }
        return response
    }
    
    @discardableResult
    public static func delete(messageAt ts: String, in channel: String) async throws -> MessageResponse {
        
        let resp = try await Chat.delete.POST
            .params(["ts": ts, "channel": channel])
            .response()
        
        guard let chatResp = try? resp.asType(ChatResponse.self),
              let response = MessageResponse(chatResp)
        else { throw SlackError.Chat(resp.JSON)  }
        return response
        
    }
}
internal struct ChatResponse: Decodable {
    
    let ok: Bool
    let channel: String
    let ts: String
    
    let text: String?
    let message: MessageObject?
    
    struct MessageObject: Decodable {
        let app_id: String
        let bot_id: String?
        let username: String?
        
        let type: String?
        let subtype: String?
        
        let text: String?
        let blocks: [Block]?
        let edited: [String: String]?
    }
}

public struct MessageResponse: Decodable {
    public let ts: String
    public let channel: String
    public let message: Message
    
    init?(_ resp: ChatResponse, message: Message? = nil) {
        
        ts = resp.ts
        channel = resp.channel
        guard message == nil
        else { self.message = message!; return }
        
        let text = resp.text ?? resp.message?.text
        guard let text else { return nil }
        
        var message_ = Message(text)
        guard let msg = resp.message else { return nil }
        if let blocks = msg.blocks {
            message_.blocks = blocks
        }
        self.message = message_
    }
    
    @discardableResult
    public func update(to newMessage: Message, author: Author? = nil) async throws -> MessageResponse {
        
        let resp = try await Chat.update.POST
            .messageAt(ts, in: channel)
            .message(newMessage)
            .response()
        
        guard let chatResp = try? resp.asType(ChatResponse.self),
              let response = MessageResponse(chatResp)
        else { throw SlackError.Chat(resp.JSON)  }
        return response
    }
    
    @discardableResult
    public func delete(as author: Author? = nil) async throws -> MessageResponse {
        
        let resp = try await Chat.delete.POST
            .params(["ts": ts, "channel": channel])
            .from(author)
            .response()
        
        guard let chatResp = try? resp.asType(ChatResponse.self),
              let response = MessageResponse(chatResp, message: message)
        else { throw SlackError.Chat(resp.JSON)  }
        return response
        
    }
}
