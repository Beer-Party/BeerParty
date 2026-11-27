import AuthenticationServices
import CryptoKit
import Foundation

/// The parts of "Sign in with Apple" that are not UI. Apple signs the user in
/// on the phone and hands the app an identity token; Supabase checks that
/// token and opens the session (`signInWithIdToken`).
///
/// The nonce ties the two together: the app makes up a random string, gives
/// Apple its SHA-256, and gives Supabase the string itself. A token that was
/// made for another sign-in attempt does not fit and is refused.
enum AppleSignIn {
  private static let nonceCharacters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

  /// A random string for one sign-in attempt.
  static func randomNonce(length: Int = 32) -> String {
    var generator = SystemRandomNumberGenerator()
    return randomNonce(length: length, using: &generator)
  }

  static func randomNonce<Generator: RandomNumberGenerator>(
    length: Int,
    using generator: inout Generator
  ) -> String {
    String((0..<max(length, 0)).map { _ in
      nonceCharacters[Int.random(in: 0..<nonceCharacters.count, using: &generator)]
    })
  }

  /// The SHA-256 of the text as small hexadecimal letters, the form Apple
  /// expects for `request.nonce`.
  static func sha256(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

  /// The user closed Apple's sheet. Not a failure worth a message.
  static func isCancellation(_ error: Error) -> Bool {
    (error as? ASAuthorizationError)?.code == .canceled
  }

  /// The identity token as the text Supabase wants, or nil when Apple's answer
  /// has none.
  static func identityToken(from tokenData: Data?) -> String? {
    guard let tokenData, let token = String(data: tokenData, encoding: .utf8), !token.isEmpty else {
      return nil
    }
    return token
  }
}
