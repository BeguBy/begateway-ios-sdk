//
//  BG PublicKey.swift
//  begateway
//
//  Created by FEDAR TRUKHAN on 9/2/19.
//

import Foundation

class BGPublicKey: BGKey {
    
    /// Reference to the key within the keychain
    let reference: SecKey
    
    /// Data of the public key as provided when creating the key.
    /// Note that if the key was created from a base64string / DER string / PEM file / DER file,
    /// the data holds the actual bytes of the key, not any textual representation like PEM headers
    /// or base64 characters.
    let originalData: Data?
    
    let tag: String? // Only used on iOS 8/9
    
    /// Returns a PEM representation of the public key.
    ///
    /// - Returns: Data of the key, PEM-encoded
    /// - Throws: SwiftyRSAError
    func pemString() throws -> String {
        let data = try self.data()
        let pem = BGRSA.format(keyData: data, withPemType: "RSA PUBLIC KEY")
        return pem
    }
    
    /// Creates a public key with a keychain key reference.
    /// This initializer will throw if the provided key reference is not a public RSA key.
    ///
    /// - Parameter reference: Reference to the key within the keychain.
    /// - Throws: SwiftyRSAError
    required init(reference: SecKey) throws {
        
        guard BGRSA.isValidKeyReference(reference, forClass: kSecAttrKeyClassPublic) else {
            throw BGRSAError.notAPublicKey
        }
        
        self.reference = reference
        self.tag = nil
        self.originalData = nil
    }
    
    /// Data of the public key as returned by the keychain.
    /// This method throws if SwiftyRSA cannot extract data from the key.
    ///
    /// - Returns: Data of the public key as returned by the keychain.
    /// - Throws: SwiftyRSAError
    required init(data: Data) throws {
        
        let tag = UUID().uuidString
        self.tag = tag
        
        self.originalData = data
        let dataWithoutHeader = try BGRSA.stripKeyHeader(keyData: data)
        
        reference = try BGRSA.addKey(dataWithoutHeader, isPublic: true, tag: tag)
    }
    
    static let publicKeyRegex: NSRegularExpression? = {
        let publicKeyRegex = "(-----BEGIN PUBLIC KEY-----.+?-----END PUBLIC KEY-----)"
        return try? NSRegularExpression(pattern: publicKeyRegex, options: .dotMatchesLineSeparators)
    }()
    
    /// Takes an input string, scans for public key sections, and then returns a PublicKey for any valid keys found
    /// - This method scans the file for public key armor - if no keys are found, an empty array is returned
    /// - Each public key block found is "parsed" by `publicKeyFromPEMString()`
    /// - should that method throw, the error is _swallowed_ and not rethrown
    ///
    /// - parameter pemString: The string to use to parse out values
    ///
    /// - returns: An array of `PublicKey` objects
    static func publicKeys(pemEncoded pemString: String) -> [BGPublicKey] {
        
        // If our regexp isn't valid, or the input string is empty, we can't move forward…
        guard let publicKeyRegexp = publicKeyRegex, pemString.count > 0 else {
            return []
        }
        
        let all = NSRange(
            location: 0,
            length: pemString.count
        )
        
        let matches = publicKeyRegexp.matches(
            in: pemString,
            options: NSRegularExpression.MatchingOptions(rawValue: 0),
            range: all
        )
        
        let keys = matches.compactMap { result -> BGPublicKey? in
            
            let match = result.range(at: 1)
            let start = pemString.index(pemString.startIndex, offsetBy: match.location)
            let end = pemString.index(start, offsetBy: match.length)
            
            let thisKey = pemString[start..<end]
            
            return try? BGPublicKey(pemEncoded: String(thisKey))
        }
        
        return keys
    }
    
    deinit {
        if let tag = tag {
            BGRSA.removeKey(tag: tag)
        }
    }
}