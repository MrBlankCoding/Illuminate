//
//  Password.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//


// I know jack shit about secuitry so maybe encript this later??
// Idk...
import Foundation
import SwiftData

@Model
final class Password {
    var profileID: UUID
    var url: String
    var username: String
    var passwordData: String 
    var createdAt: Date
    
    init(profileID: UUID, url: String, username: String, passwordData: String) {
        self.profileID = profileID
        self.url = url
        self.username = username
        self.passwordData = passwordData
        self.createdAt = Date()
    }
}
