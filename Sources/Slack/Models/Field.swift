//
//  Field.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

public struct Field: Codable {
    
    public let label: String
    public let value: String?
    public let alt: String?
    
}


struct ProfileResponse: Decodable {
    
    let profile: ProfileSchema?
    
    
    
}

