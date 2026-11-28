import Foundation

/// The parts of "sign in with an email code" that are not UI. The user types
/// an address, Supabase mails a one-time code to it (`signInWithOTP`), and the
/// app hands the typed code back to Supabase (`verifyOTP`), which opens the
/// session.
enum EmailSignIn {
  /// Supabase sends six digits unless the project is set to a longer code;
  /// the setting allows up to ten.
  static let minimumCodeLength = 6
  static let maximumCodeLength = 10
  /// How long "Send again" stays off after a code was sent. Supabase refuses
  /// a second mail to the same address within a minute anyway.
  static let resendWait: TimeInterval = 60

  /// The address as it is sent: without the spaces and line breaks that
  /// pasting and autofill add around it.
  static func cleanedEmail(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Whether the text looks like an address a mail could reach: one "@",
  /// something before it, and a domain with a dot that neither starts nor
  /// ends with one. Only meant to catch slips; Supabase has the last word.
  static func isPlausibleEmail(_ text: String) -> Bool {
    let email = cleanedEmail(text)
    guard email.count <= 254, !email.contains(where: { $0.isWhitespace }) else { return false }

    let parts = email.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2 else { return false }
    let name = parts[0]
    let domain = parts[1]
    guard !name.isEmpty, !domain.isEmpty else { return false }

    let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2 else { return false }
    return labels.allSatisfy { !$0.isEmpty }
  }

  /// The typed code with everything but the digits 0 to 9 removed (a pasted
  /// code often comes with spaces or a dash), cut to the longest code there
  /// is.
  static func cleanedCode(_ text: String) -> String {
    String(text.filter { $0.isASCII && $0.isNumber }.prefix(maximumCodeLength))
  }

  /// Whether the typed code is long enough to be sent for checking.
  static func isCompleteCode(_ text: String) -> Bool {
    cleanedCode(text).count >= minimumCodeLength
  }

  /// The seconds until another code may be asked for; 0 when it may be now.
  static func secondsUntilResend(lastSentAt: Date?, now: Date) -> Int {
    guard let lastSentAt else { return 0 }
    let remaining = resendWait - now.timeIntervalSince(lastSentAt)
    guard remaining > 0 else { return 0 }
    return min(Int(remaining.rounded(.up)), Int(resendWait))
  }
}
