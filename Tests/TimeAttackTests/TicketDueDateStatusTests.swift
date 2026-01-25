import XCTest

@testable import TimeAttackCore

final class TicketDueDateStatusTests: XCTestCase {

    // MARK: - displayText

    func test_displayText_overdue_withOneDay_returnsSingularForm() {
        XCTAssertEqual(TicketDueDateStatus.overdue(days: 1).displayText, "1일 지남")
    }

    func test_displayText_overdue_withMultipleDays_returnsPluralForm() {
        XCTAssertEqual(TicketDueDateStatus.overdue(days: 3).displayText, "3일 지남")
    }

    func test_displayText_today_returnsTodayMessage() {
        XCTAssertEqual(TicketDueDateStatus.today.displayText, "오늘 마감")
    }

    func test_displayText_soon_withOneDay_returnsTomorrowMessage() {
        XCTAssertEqual(TicketDueDateStatus.soon(days: 1).displayText, "내일 마감")
    }

    func test_displayText_soon_withMultipleDays_returnsDaysRemaining() {
        XCTAssertEqual(TicketDueDateStatus.soon(days: 2).displayText, "2일 남음")
        XCTAssertEqual(TicketDueDateStatus.soon(days: 3).displayText, "3일 남음")
    }

    func test_displayText_normal_returnsDaysRemaining() {
        XCTAssertEqual(TicketDueDateStatus.normal(days: 7).displayText, "7일 남음")
        XCTAssertEqual(TicketDueDateStatus.normal(days: 10).displayText, "10일 남음")
    }

    func test_displayText_none_returnsEmptyString() {
        XCTAssertEqual(TicketDueDateStatus.none.displayText, "")
    }

    // MARK: - color

    func test_color_overdue_returnsRed() {
        XCTAssertEqual(TicketDueDateStatus.overdue(days: 1).color, "red")
        XCTAssertEqual(TicketDueDateStatus.overdue(days: 5).color, "red")
    }

    func test_color_today_returnsOrange() {
        XCTAssertEqual(TicketDueDateStatus.today.color, "orange")
    }

    func test_color_soon_returnsYellow() {
        XCTAssertEqual(TicketDueDateStatus.soon(days: 1).color, "yellow")
        XCTAssertEqual(TicketDueDateStatus.soon(days: 2).color, "yellow")
    }

    func test_color_normal_returnsSecondary() {
        XCTAssertEqual(TicketDueDateStatus.normal(days: 10).color, "secondary")
    }

    func test_color_none_returnsClear() {
        XCTAssertEqual(TicketDueDateStatus.none.color, "clear")
    }
}
