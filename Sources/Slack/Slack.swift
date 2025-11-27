//
//  Slack.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation
@_exported import Tapioca

@MainActor
public struct Slack: Tapioca {
    public typealias R = Request
    public static var baseURL: URL = URL(string: "https://slack.com/api")!
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public static var defaultAuthor: Author? = nil
    
    //--------------------------------------
    // MARK: - PRE- & POST-PROCESS -
    //--------------------------------------
    public static func preProcess(request: R) async throws -> R {
        var request = request
        
        // MARK: Authorship
        if request.headers["Authorization"] == nil, let defaultAuthor {
            request = request
                .from(defaultAuthor)
        }
        
        return request
            .content(type: request.content)
            .accepts(type: request.accepts)
    }
    public static func postProcess(response: Response, from request: R) async throws -> Response {
        
        // MARK: Error Handling
        guard let statusCode = response.statusCode
        else { throw PrestoError.noStatusCode }
        
        guard statusCode != 200
        else { return response }
        
        print("Status Code: \(statusCode)")
        
        switch statusCode {
        case 404:
            print(response)
        default:
            break
        }
        
        return response
    }
}
