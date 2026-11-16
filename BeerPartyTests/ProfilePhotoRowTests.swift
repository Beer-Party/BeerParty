import XCTest
@testable import BeerParty

@MainActor
final class ProfilePhotoRowTests: XCTestCase {

  func testPathsAreKeyedByUser() {
    let a = UUID()
    let b = UUID()
    let paths = ProfilePhotoRow.pathsByUserID([
      ProfilePhotoRow(id: a, profilePicPath: "a/avatar.jpg"),
      ProfilePhotoRow(id: b, profilePicPath: "b/avatar.jpg"),
    ])
    XCTAssertEqual(paths, [a: "a/avatar.jpg", b: "b/avatar.jpg"])
  }

  func testUsersWithoutPictureHaveNoEntry() {
    let a = UUID()
    let b = UUID()
    let paths = ProfilePhotoRow.pathsByUserID([
      ProfilePhotoRow(id: a, profilePicPath: nil),
      ProfilePhotoRow(id: b, profilePicPath: "b/avatar.jpg"),
    ])
    XCTAssertEqual(paths, [b: "b/avatar.jpg"])
  }

  func testNoRowsGiveNoPaths() {
    XCTAssertTrue(ProfilePhotoRow.pathsByUserID([]).isEmpty)
  }

  // The request returns one object per profile, in the shape PostgREST sends.
  func testRowsDecodeFromJSON() throws {
    let id = UUID()
    let json = """
    [{"id": "\(id.uuidString)", "profile_pic_path": "x/avatar.jpg"},
     {"id": "\(UUID().uuidString)", "profile_pic_path": null}]
    """
    let rows = try JSONDecoder().decode([ProfilePhotoRow].self, from: Data(json.utf8))
    XCTAssertEqual(ProfilePhotoRow.pathsByUserID(rows), [id: "x/avatar.jpg"])
  }
}
