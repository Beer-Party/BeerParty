import XCTest
@testable import BeerParty

@MainActor
final class LobbyEventFeedTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)
  private let anna = UUID()
  private let ben = UUID()

  private func time(_ secondsLater: TimeInterval) -> Date {
    start.addingTimeInterval(secondsLater)
  }

  // MARK: rows of the two sources

  private func homeRow(_ user: UUID, nickname: String = "Anna", at seconds: TimeInterval) -> LobbyDrink {
    LobbyDrink(
      id: UUID(), userId: user,
      name: "\(LobbyBackendService.madeItHomeDrinkPrefix)\(nickname)",
      volumeMl: 0, abv: 0, consumedAt: time(seconds)
    )
  }

  private func closedRow(_ user: UUID, at seconds: TimeInterval) -> LobbyDrink {
    // No time in the name, so the row's own time counts.
    LobbyDrink(
      id: UUID(), userId: user,
      name: "\(LobbyBackendService.lobbyClosedDrinkPrefix)|Host",
      volumeMl: 0, abv: 0, consumedAt: time(seconds)
    )
  }

  private func dueRow(_ user: UUID, motion: UUID, target: String = "Bar Nine", at seconds: TimeInterval) -> LobbyDrink {
    LobbyDrink(
      id: UUID(), userId: user,
      name: "\(LobbyBackendService.motionArrivedDrinkPrefix)\(motion.uuidString)|\(target)",
      volumeMl: 0, abv: 0, consumedAt: time(seconds)
    )
  }

  private func event(
    _ kind: LobbyEventKind,
    _ user: UUID,
    motion: UUID? = nil,
    at seconds: TimeInterval
  ) -> LobbyEventRecord {
    LobbyEventRecord(id: UUID(), kind: kind, userId: user, motionId: motion, createdAt: time(seconds))
  }

  private func merge(
    known: [LobbyNotice] = [],
    rows: [LobbyDrink] = [],
    events: [LobbyEventRecord] = []
  ) -> (all: [LobbyNotice], fresh: [LobbyNotice]) {
    LobbyEventFeed.merge(
      known: known,
      incoming: LobbyEventFeed.notices(fromDrinkRows: rows) + LobbyEventFeed.notices(fromEvents: events)
    )
  }

  // MARK: reading

  func testRealDrinksAreNotNotices() {
    let beer = LobbyDrink(id: UUID(), userId: anna, name: "Beer", volumeMl: 330, abv: 5, consumedAt: start)
    XCTAssertTrue(LobbyEventFeed.notices(fromDrinkRows: [beer]).isEmpty)
  }

  func testPrefixedRowsAreRead() {
    let motion = UUID()
    let notices = LobbyEventFeed.notices(fromDrinkRows: [
      homeRow(anna, at: 0),
      closedRow(ben, at: 10),
      dueRow(ben, motion: motion, at: 20)
    ])

    XCTAssertEqual(notices.map(\.kind), [.madeItHome, .lobbyClosed, .motionDue])
    XCTAssertEqual(notices[0].nickname, "Anna")
    XCTAssertEqual(notices[0].userId, anna)
    XCTAssertEqual(notices[1].at, time(10))
    XCTAssertEqual(notices[2].motionId, motion)
    XCTAssertEqual(notices[2].targetText, "Bar Nine")
    XCTAssertTrue(notices.allSatisfy { $0.drinkRowId != nil && $0.eventId == nil })
  }

  func testEventRowIsDecodedFromTheServersJSON() throws {
    let json = """
    [
      {"id":"11111111-1111-1111-1111-111111111111","kind":"motion_due",
       "user_id":"22222222-2222-2222-2222-222222222222",
       "motion_id":"33333333-3333-3333-3333-333333333333",
       "created_at":"2026-11-28T20:15:30.123456+00:00"},
      {"id":"44444444-4444-4444-4444-444444444444","kind":"made_it_home",
       "user_id":"22222222-2222-2222-2222-222222222222",
       "motion_id":null,
       "created_at":"2026-11-28T20:16:00+00:00"},
      {"id":"55555555-5555-5555-5555-555555555555","kind":"something_new",
       "user_id":"22222222-2222-2222-2222-222222222222",
       "motion_id":null,
       "created_at":"2026-11-28T20:17:00+00:00"}
    ]
    """
    let rows = try JSONDecoder().decode([LobbyEventRow].self, from: Data(json.utf8))
    let records = rows.compactMap(\.record)

    // The unknown kind is skipped, not an error.
    XCTAssertEqual(records.map(\.kind), [.motionDue, .madeItHome])
    XCTAssertEqual(records[0].motionId, UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
    XCTAssertNil(records[1].motionId)
    XCTAssertEqual(records[1].createdAt.timeIntervalSince(records[0].createdAt), 29.877, accuracy: 0.01)
  }

  func testTimestampTextCanBeReadBack() {
    let text = LobbyEventFeed.timestampText(start)
    XCTAssertEqual(LobbyEventFeed.parseTimestamp(text), start)
    XCTAssertNil(LobbyEventFeed.parseTimestamp("yesterday"))
  }

  // MARK: merging, one poll

  func testOnlyAnOldRowIsOneNotice() {
    let result = merge(rows: [homeRow(anna, at: 0)])
    XCTAssertEqual(result.all.count, 1)
    XCTAssertEqual(result.fresh.count, 1)
  }

  func testOnlyAnEventIsOneNotice() {
    let result = merge(events: [event(.madeItHome, anna, at: 0)])
    XCTAssertEqual(result.all.count, 1)
    XCTAssertEqual(result.fresh.count, 1)
    XCTAssertNil(result.fresh[0].nickname)
  }

  func testRowAndEventForTheSameTapAreOneNotice() {
    let result = merge(rows: [homeRow(anna, at: 0)], events: [event(.madeItHome, anna, at: 2)])

    XCTAssertEqual(result.all.count, 1)
    XCTAssertEqual(result.fresh.count, 1)
    // The notice that is announced already has both halves.
    XCTAssertEqual(result.fresh[0].nickname, "Anna")
    XCTAssertNotNil(result.fresh[0].drinkRowId)
    XCTAssertNotNil(result.fresh[0].eventId)
    // The event's time (the server's clock) wins.
    XCTAssertEqual(result.fresh[0].at, time(2))
  }

  func testAPhoneClockThatIsMinutesOffStillPairs() {
    let result = merge(rows: [homeRow(anna, at: -300)], events: [event(.madeItHome, anna, at: 0)])
    XCTAssertEqual(result.all.count, 1)
  }

  func testRowAndEventFarApartAreTwoNotices() {
    let result = merge(
      rows: [homeRow(anna, at: 0)],
      events: [event(.madeItHome, anna, at: LobbyEventFeed.twinWindow + 1)]
    )
    XCTAssertEqual(result.all.count, 2)
  }

  func testTwoMembersGettingHomeAtTheSameTimeAreTwoNotices() {
    let result = merge(
      rows: [homeRow(anna, at: 0), homeRow(ben, nickname: "Ben", at: 1)],
      events: [event(.madeItHome, anna, at: 1), event(.madeItHome, ben, at: 2)]
    )
    XCTAssertEqual(result.all.count, 2)
    XCTAssertEqual(Set(result.all.map(\.userId)), [anna, ben])
    XCTAssertTrue(result.all.allSatisfy { $0.drinkRowId != nil && $0.eventId != nil })
  }

  func testTwoRealTapsMinutesApartStayTwoNotices() {
    // Each tap is written twice. Both taps are inside the window of each
    // other, and still each row finds its own twin.
    let result = merge(
      rows: [homeRow(anna, at: 0), homeRow(anna, at: 180)],
      events: [event(.madeItHome, anna, at: 1), event(.madeItHome, anna, at: 181)]
    )

    XCTAssertEqual(result.all.count, 2)
    XCTAssertEqual(result.fresh.count, 2)
    XCTAssertEqual(result.all.map(\.at).sorted(), [time(1), time(181)])
    XCTAssertTrue(result.all.allSatisfy { $0.drinkRowId != nil && $0.eventId != nil })
  }

  func testTwoOldRowsFromOneMemberAreNeverMerged() {
    // A phone on the old version: rows only.
    let result = merge(rows: [homeRow(anna, at: 0), homeRow(anna, at: 5)])
    XCTAssertEqual(result.all.count, 2)
  }

  func testClosedRowAndEventAreOneNoticeHoweverFarApart() {
    let result = merge(rows: [closedRow(anna, at: 0)], events: [event(.lobbyClosed, anna, at: 3_600)])
    XCTAssertEqual(result.all.count, 1)
    XCTAssertEqual(LobbyEventFeed.closedAt(in: result.all), time(3_600))
  }

  func testMotionDuePairsByMotion() {
    let first = UUID()
    let second = UUID()
    let result = merge(
      rows: [dueRow(anna, motion: first, at: 0), dueRow(anna, motion: second, target: "Home", at: 1)],
      // Another phone may have written the event: the member differs.
      events: [event(.motionDue, ben, motion: second, at: 2)]
    )

    XCTAssertEqual(result.all.count, 2)
    let paired = result.all.first { $0.eventId != nil }
    XCTAssertEqual(paired?.motionId, second)
    XCTAssertEqual(paired?.targetText, "Home")
  }

  // MARK: merging, across polls

  func testEventArrivingAPollAfterItsRowIsNotFresh() {
    let firstPoll = merge(rows: [homeRow(anna, at: 0)])
    let secondPoll = merge(known: firstPoll.all, events: [event(.madeItHome, anna, at: 1)])

    XCTAssertEqual(secondPoll.all.count, 1)
    XCTAssertTrue(secondPoll.fresh.isEmpty)
    XCTAssertNotNil(secondPoll.all[0].eventId)
    XCTAssertEqual(secondPoll.all[0].nickname, "Anna")
  }

  func testRowArrivingAPollAfterItsEventIsNotFresh() {
    let firstPoll = merge(events: [event(.madeItHome, anna, at: 1)])
    let secondPoll = merge(known: firstPoll.all, rows: [homeRow(anna, at: 0)])

    XCTAssertEqual(secondPoll.all.count, 1)
    XCTAssertTrue(secondPoll.fresh.isEmpty)
    XCTAssertEqual(secondPoll.all[0].nickname, "Anna")
    // Still the event's time.
    XCTAssertEqual(secondPoll.all[0].at, time(1))
  }

  func testTheSameRowsReadAgainAreSkipped() {
    let row = homeRow(anna, at: 0)
    let home = event(.madeItHome, anna, at: 1)
    let firstPoll = merge(rows: [row], events: [home])
    let secondPoll = merge(known: firstPoll.all, rows: [row], events: [home])

    XCTAssertEqual(secondPoll.all, firstPoll.all)
    XCTAssertTrue(secondPoll.fresh.isEmpty)
  }

  func testASecondTapInALaterPollIsFresh() {
    let firstPoll = merge(rows: [homeRow(anna, at: 0)], events: [event(.madeItHome, anna, at: 1)])
    let secondPoll = merge(
      known: firstPoll.all,
      rows: [homeRow(anna, at: 120)],
      events: [event(.madeItHome, anna, at: 121)]
    )

    XCTAssertEqual(secondPoll.all.count, 2)
    XCTAssertEqual(secondPoll.fresh.count, 1)
    XCTAssertEqual(secondPoll.fresh[0].at, time(121))
  }

  // MARK: cursor and closed time

  func testEventCursorIsTheNewestEventTime() {
    XCTAssertNil(LobbyEventFeed.eventCursor(in: merge(rows: [homeRow(anna, at: 500)]).all))

    let result = merge(
      rows: [homeRow(anna, at: 500)],
      events: [event(.madeItHome, ben, at: 10), event(.lobbyClosed, ben, at: 40)]
    )
    XCTAssertEqual(LobbyEventFeed.eventCursor(in: result.all), time(40))
  }

  func testClosedAtIsNilWithoutAClosedNotice() {
    XCTAssertNil(LobbyEventFeed.closedAt(in: merge(rows: [homeRow(anna, at: 0)]).all))
  }

  // MARK: what is announced

  private func announcement(
    _ fresh: [LobbyNotice],
    nicknames: [UUID: String] = [:],
    targets: [UUID: String] = [:]
  ) -> LobbyAnnouncement? {
    LobbyEventFeed.announcement(
      for: fresh,
      nickname: { nicknames[$0] },
      motionTarget: { targets[$0] }
    )
  }

  func testNothingNewSaysNothing() {
    XCTAssertNil(announcement([]))
  }

  func testClosingComesBeforeMotionAndHome() {
    let fresh = merge(
      rows: [homeRow(anna, at: 0), dueRow(anna, motion: UUID(), at: 1), closedRow(ben, at: 2)]
    ).fresh
    XCTAssertEqual(announcement(fresh), .lobbyClosed(at: time(2)))
  }

  func testMotionComesBeforeHome() {
    let fresh = merge(rows: [dueRow(anna, motion: UUID(), at: 1), homeRow(anna, at: 5)]).fresh
    XCTAssertEqual(announcement(fresh), .motionDue(target: "Bar Nine"))
  }

  func testMotionTargetComesFromTheLoadedMotion() {
    let motion = UUID()
    let fresh = merge(events: [event(.motionDue, anna, motion: motion, at: 0)]).fresh

    XCTAssertEqual(announcement(fresh, targets: [motion: "The kebab place"]), .motionDue(target: "The kebab place"))
    // The motion is not loaded yet.
    XCTAssertEqual(announcement(fresh), .motionDue(target: "the destination"))
  }

  func testHomeUsesTheRosterNicknameThenTheRowsThenMember() {
    let both = merge(rows: [homeRow(anna, nickname: "Queen Anna", at: 0)], events: [event(.madeItHome, anna, at: 1)]).fresh
    XCTAssertEqual(announcement(both, nicknames: [anna: "Anna"]), .madeItHome(nickname: "Anna"))
    XCTAssertEqual(announcement(both), .madeItHome(nickname: "Queen Anna"))

    let eventOnly = merge(events: [event(.madeItHome, anna, at: 1)]).fresh
    XCTAssertEqual(announcement(eventOnly), .madeItHome(nickname: "Member"))
    XCTAssertEqual(announcement(eventOnly, nicknames: [anna: "  "]), .madeItHome(nickname: "Member"))
  }

  func testTheLatestOfSeveralIsAnnounced() {
    let fresh = merge(rows: [homeRow(ben, nickname: "Ben", at: 30), homeRow(anna, at: 10)]).fresh
    XCTAssertEqual(announcement(fresh), .madeItHome(nickname: "Ben"))
  }
}
