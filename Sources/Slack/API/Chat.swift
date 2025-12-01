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
    
    var path: URL { Self.base.appending(component: "chat.\(rawValue)") }
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
    
    public static func delete(messageAt ts: String, in channel: Channel, authority: Author? = nil) async throws {
        
        let resp = try await Chat.delete.POST
            .params(["ts": ts, "channel": channel.id])
            .from(authority)
            .response()
        
        guard let chatResp = try? resp.asType(ChatResponse.self)
        else { throw SlackError.Chat(resp.JSON)  }
    }
}
internal struct ChatResponse: Decodable {
    
    let ok: Bool
    let channel: String
    let ts: String
    
    let text: String?
    let message: Message?
}

public struct MessageResponse: Decodable {
    public let ts: String
    public let channel: Channel
    public let message: Message
    
    init?(_ resp: ChatResponse, message: Message? = nil) {
        
        ts = resp.ts
        channel = Channel(resp.channel)
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
    
    internal init?(_ msg: Message, channel: Channel) {
        guard let ts = msg.ts else { return nil }
        self.ts = ts
        self.channel = channel
        self.message = msg
    }
    
    @discardableResult
    public func update(to newMessage: Message, author: Author? = nil) async throws -> MessageResponse {
        
        let resp = try await Chat.update.POST
            .messageAt(ts, in: channel.id)
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
            .params(["ts": ts, "channel": channel.id])
            .from(author)
            .response()
        
        guard let chatResp = try? resp.asType(ChatResponse.self),
              let response = MessageResponse(chatResp, message: message)
        else { throw SlackError.Chat(resp.JSON)  }
        return response
        
    }
}
