import XCTest
@testable import BeerParty

@MainActor
final class ProfilePhotoPathTests: XCTestCase {

  private let user = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
  private let other = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

  func testLegacyPathIsTheOneUsedBefore() {
    XCTAssertEqual(
      ProfilePhotoPath.legacyPath(userID: user),
      "11111111-2222-3333-4444-555555555555/avatar.jpg"
    )
  }

  func testNewPathIsInTheUsersFolderAndCarriesTheTime() {
    let path = ProfilePhotoPath.newPath(userID: user, at: Date(timeIntervalSince1970: 1_800_000_000.9))
    XCTAssertEqual(path, "11111111-2222-3333-4444-555555555555/avatar-1800000000.jpg")
  }

  // The point of the change: a second upload gets a different link.
  func testTwoUploadsGetDifferentPaths() {
    let first = ProfilePhotoPath.newPath(userID: user, at: Date(timeIntervalSince1970: 1_800_000_000))
    let second = ProfilePhotoPath.newPath(userID: user, at: Date(timeIntervalSince1970: 1_800_000_060))
    XCTAssertNotEqual(first, second)
    XCTAssertNotEqual(first, ProfilePhotoPath.legacyPath(userID: user))
  }

  func testOldPhotoIsRemovedAfterAReplacement() {
    let old = ProfilePhotoPath.legacyPath(userID: user)
    let new = ProfilePhotoPath.newPath(userID: user, at: Date(timeIntervalSince1970: 1_800_000_000))
    XCTAssertEqual(ProfilePhotoPath.replacedPath(old: old, new: new, userID: user), old)
  }

  func testNothingIsRemovedWhenThePathDidNotChange() {
    let path = ProfilePhotoPath.legacyPath(userID: user)
    XCTAssertNil(ProfilePhotoPath.replacedPath(old: path, new: path, userID: user))
  }

  func testNothingIsRemovedWithoutAnOldOrANewPhoto() {
    let path = ProfilePhotoPath.legacyPath(userID: user)
    XCTAssertNil(ProfilePhotoPath.replacedPath(old: nil, new: path, userID: user))
    XCTAssertNil(ProfilePhotoPath.replacedPath(old: "", new: path, userID: user))
    XCTAssertNil(ProfilePhotoPath.replacedPath(old: path, new: nil, userID: user))
    XCTAssertNil(ProfilePhotoPath.replacedPath(old: path, new: "", userID: user))
  }

  // A stored path that points into someone else's folder is never deleted.
  func testAFileOutsideTheUsersFolderIsNeverRemoved() {
    let foreign = ProfilePhotoPath.legacyPath(userID: other)
    let new = ProfilePhotoPath.newPath(userID: user, at: Date(timeIntervalSince1970: 1_800_000_000))
    XCTAssertNil(ProfilePhotoPath.replacedPath(old: foreign, new: new, userID: user))
  }

  func testFolderMatchIgnoresLetterCase() {
    let old = "\(other.uuidString.lowercased())/avatar.jpg"
    let new = ProfilePhotoPath.newPath(userID: other, at: Date(timeIntervalSince1970: 1_800_000_000))
    XCTAssertEqual(ProfilePhotoPath.replacedPath(old: old, new: new, userID: other), old)
  }
}
