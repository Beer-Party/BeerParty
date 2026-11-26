import XCTest
@testable import BeerParty

@MainActor
final class LobbyRosterTests: XCTestCase {

  func testSameMembersInAnyOrderNeedNoReload() {
    let a = UUID()
    let b = UUID()
    XCTAssertFalse(LobbyRoster.needsReload(shownMemberIDs: [a, b], latestMemberIDs: [b, a]))
    XCTAssertFalse(LobbyRoster.needsReload(shownMemberIDs: [], latestMemberIDs: []))
  }

  func testMemberJoiningNeedsReload() {
    let a = UUID()
    XCTAssertTrue(LobbyRoster.needsReload(shownMemberIDs: [a], latestMemberIDs: [a, UUID()]))
  }

  func testMemberLeavingNeedsReload() {
    let a = UUID()
    XCTAssertTrue(LobbyRoster.needsReload(shownMemberIDs: [a, UUID()], latestMemberIDs: [a]))
  }

  // MARK: members without BAC values

  func testMemberWithoutBACValuesIsNoticed() {
    let a = UUID()
    let b = UUID()
    let params = [a: values(a, tbw: 40)]
    XCTAssertTrue(LobbyRoster.hasMemberWithoutBACValues(memberIDs: [a, b], paramsByUserId: params))
  }

  func testEveryMemberWithBACValuesIsFine() {
    let a = UUID()
    let params = [a: values(a, tbw: 40), UUID(): values(UUID(), tbw: 35)]
    XCTAssertFalse(LobbyRoster.hasMemberWithoutBACValues(memberIDs: [a], paramsByUserId: params))
    XCTAssertFalse(LobbyRoster.hasMemberWithoutBACValues(memberIDs: [], paramsByUserId: [:]))
  }

  // MARK: does the roster differ

  private func member(_ id: UUID, _ nickname: String, photo: String? = nil) -> LobbyMemberData {
    LobbyMemberData(userId: id, nickname: nickname, profilePicPath: photo)
  }

  private func values(_ id: UUID, tbw: Double, elimination: Double = 0.15) -> LobbyBACParamsData {
    LobbyBACParamsData(userId: id, tbw: tbw, eliminationPerHourPromille: elimination)
  }

  func testSameRosterInAnotherOrderDoesNotDiffer() {
    let a = UUID()
    let b = UUID()
    let latest = LobbyRoster(
      members: [member(b, "Ben"), member(a, "Anna")],
      bacParamsByUserId: [a: values(a, tbw: 30), b: values(b, tbw: 45)]
    )
    XCTAssertFalse(LobbyRoster.differs(
      shownMembers: [member(a, "Anna"), member(b, "Ben")],
      shownParamsByUserId: [b: values(b, tbw: 45), a: values(a, tbw: 30)],
      latest: latest
    ))
  }

  // Joined again with the invite code under another name.
  func testChangedNicknameDiffers() {
    let a = UUID()
    let params = [a: values(a, tbw: 30)]
    XCTAssertTrue(LobbyRoster.differs(
      shownMembers: [member(a, "Anna")],
      shownParamsByUserId: params,
      latest: LobbyRoster(members: [member(a, "Annie")], bacParamsByUserId: params)
    ))
  }

  // Since B15 a changed profile weight rewrites the member's values.
  func testChangedBodyValuesDiffer() {
    let a = UUID()
    XCTAssertTrue(LobbyRoster.differs(
      shownMembers: [member(a, "Anna")],
      shownParamsByUserId: [a: values(a, tbw: 40)],
      latest: LobbyRoster(members: [member(a, "Anna")], bacParamsByUserId: [a: values(a, tbw: 31.5)])
    ))
    XCTAssertTrue(LobbyRoster.differs(
      shownMembers: [member(a, "Anna")],
      shownParamsByUserId: [a: values(a, tbw: 40, elimination: 0.14)],
      latest: LobbyRoster(
        members: [member(a, "Anna")],
        bacParamsByUserId: [a: values(a, tbw: 40, elimination: 0.17)]
      )
    ))
  }

  func testBACValuesArrivingLaterDiffer() {
    let a = UUID()
    XCTAssertTrue(LobbyRoster.differs(
      shownMembers: [member(a, "Anna")],
      shownParamsByUserId: [:],
      latest: LobbyRoster(members: [member(a, "Anna")], bacParamsByUserId: [a: values(a, tbw: 30)])
    ))
  }

  func testChangedPhotoDiffers() {
    let a = UUID()
    XCTAssertTrue(LobbyRoster.differs(
      shownMembers: [member(a, "Anna", photo: "a/avatar-1.jpg")],
      shownParamsByUserId: [:],
      latest: LobbyRoster(members: [member(a, "Anna", photo: "a/avatar-2.jpg")], bacParamsByUserId: [:])
    ))
  }

  func testMemberJoiningDiffers() {
    let a = UUID()
    XCTAssertTrue(LobbyRoster.differs(
      shownMembers: [member(a, "Anna")],
      shownParamsByUserId: [:],
      latest: LobbyRoster(members: [member(a, "Anna"), member(UUID(), "Ben")], bacParamsByUserId: [:])
    ))
  }
}
