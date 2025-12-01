//
//  Channel.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

import Foundation

public struct Channel: Codable {
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public let id: String
    
    public var created: Int?
    public var creator: String?
    
    public var name: String?
    public var name_normalized: String?
    public var num_members: Int?
    public var purpose: Purpose?
    public var topic: Purpose?
    
    public var is_archived: Bool?
    public var is_channel: Bool?
    public var is_private: Bool?
    public var is_mpim: Bool?
    public var is_im: Bool?
    public var is_member: Bool?
    
    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(_ id: String) { self.id = id }
    
    //--------------------------------------
    // MARK: - HELPERS -
    //--------------------------------------
    internal var type: ChannelType {
        if let is_mpim, is_mpim { return .mpim }
        if let is_private, is_private { return .priv }
        if let is_im, is_im { return .im }
        return .open
    }
}
extension Channel: CustomStringConvertible {
    public var description: String {
        var channel = ""
        if let is_archived, is_archived { channel += "Archived " }

        if name == nil, type == .im {
            return "DM(ID: \(id))"
        }
        
        channel += "Channel("
        if let name { channel += "\(type.rawValue)\(name), " }
        channel += "ID: \(id)"
        if let num_members { channel += ", members: \(num_members)" }
        if let purpose = purpose?.value, purpose != "" { channel += ", purpose: \(purpose)" }
        if let topic = topic?.value, topic != "" { channel += ", topic: \(topic)" }
        return channel + ")"
    }
}
extension Channel {
    
    public struct Purpose: Codable {
        public var creator: String?
        public var last_set: Int?
        public var value: String?
    }
}
internal enum ChannelType: String {
    case open = "#"
    case priv = "🔒"
    case mpim = "᠅"
    case im = "💬"
}
