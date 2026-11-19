import Foundation

/// Turns an error into a sentence for a status line. The system's own
/// descriptions ("The operation couldn’t be completed. (NSURLErrorDomain
/// error -1009.)", raw server messages) mean little to a user, so they are not
/// shown. The result is "Couldn't <action>." followed by what to do about it.
enum UserFacingError {
  static let offline = "You seem to be offline. Check your connection and try again."
  static let timedOut = "The server took too long to answer. Please try again."
  static let serverUnreachable = "The server can't be reached right now. Try again in a moment."
  static let generic = "Please try again."

  /// - Parameter action: what was being attempted, worded to follow "Couldn't",
  ///   for example "add the drink".
  static func message(couldNot action: String, error: Error) -> String {
    if let ownMessage = appMessage(for: error) {
      return ownMessage
    }
    return "Couldn't \(action). \(advice(for: error))"
  }

  /// The app's own errors already carry a sentence written for the user
  /// ("Only the lobby creator can perform this action."); it is shown as it is.
  static func appMessage(for error: Error) -> String? {
    guard error is LobbyJoinError
      || error is LobbyLifecycleError
      || error is LobbyCreationError
      || error is DrinkMutationError
      || error is ProfileImageError
    else { return nil }
    return (error as? LocalizedError)?.errorDescription
  }

  static func advice(for error: Error) -> String {
    guard let urlError = error as? URLError else { return generic }
    switch urlError.code {
    case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
      return offline
    case .timedOut:
      return timedOut
    case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .secureConnectionFailed:
      return serverUnreachable
    default:
      return generic
    }
  }
}
