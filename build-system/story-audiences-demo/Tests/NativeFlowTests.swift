import XCTest

final class NativeFlowTests: XCTestCase {
    let app = XCUIApplication(bundleIdentifier: "design.storyaudiences.native")
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--story-audiences-demo", name.contains("FigmaDefault") ? "--story-audiences-figma-review" : "--story-audiences-test-data", "--story-audiences-assets", URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Assets").path]
        if name.contains("FigmaDefault") { app.launchArguments += ["--story-audiences-test-run-id", UUID().uuidString] }
        app.launch()
    }
    func visible(_ text: String, in container: XCUIElement? = nil, timeout: TimeInterval = 15) -> XCUIElement {
        let predicate = text == "My Story" ? NSPredicate(format: "label ==[c] 'My Story' OR label ==[c] 'Your Story'") : NSPredicate(format: "label ==[c] %@ OR identifier == %@ OR label BEGINSWITH[c] %@", text, text, text)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let result = (container ?? app).buttons.matching(predicate).allElementsBoundByIndex.first(where: { $0.isHittable }) { return result }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        XCTFail("No visible element: \(text)\n\(app.debugDescription)")
        return app
    }
    func capture(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
        let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = name + "-accessibility"; hierarchy.lifetime = .keepAlways; add(hierarchy)
    }
    func testFigmaDefaultFirstPersonHeaderMotion() throws {
        visible("Next", timeout: 90).tap()
        visible("Create List").tap()
        let people = app.otherElements["storyAudiencePeopleScreen"]
        capture("visual-first-person-empty")
        visible("Sonya Litvinova", in: people).tap()
        capture("visual-first-person-selected")
        visible("Deselect All", in: people).tap()
        capture("visual-first-person-cleared")
        visible("Marina", in: people).tap()
        capture("visual-first-person-reselected")
        visible("daria", in: people).tap()
        capture("visual-first-person-second-selected")
    }
    func testFigmaDefaultBackdropDrag() throws {
        let next = visible("Next", timeout: 90)
        capture("defect-source-uncovered")
        next.tap()
        _ = visible("Create List")
        capture("visual-backdrop-before-drag")
        let header = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.13))
        header.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.23)), withVelocity: XCUIGestureVelocity(rawValue: 85), thenHoldForDuration: 0.3)
        _ = visible("Create List")
        capture("visual-backdrop-cancelled-drag")
        for _ in 0 ..< 2 {
            header.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.43)), withVelocity: XCUIGestureVelocity(rawValue: 110), thenHoldForDuration: 0.4)
            _ = visible("Create List")
        }
        capture("visual-backdrop-repeated-rebound")
        header.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)), withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.1)
        _ = visible("Next")
        capture("visual-backdrop-dismissed")
        visible("Next").tap()
        _ = visible("Create List")
        capture("visual-backdrop-reopened")
    }
    func testFigmaDefaultListNavigationAndMove() throws {
        visible("Next", timeout: 90).tap()
        capture("visual-compose-backdrop")
        visible("Create List").tap()
        let people = app.otherElements["storyAudiencePeopleScreen"]
        visible("Marina", in: people).tap()
        visible("Next", in: people).tap()
        let field = app.textFields["storyAudienceName"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap(); field.typeText("Weekend plans\n")
        visible("Back").tap()
        _ = visible("Next", in: people)
        capture("new-creation-back-to-people")
        visible("Next", in: people).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "Weekend plans")
        visible("Edit people").tap()
        _ = visible("Next", in: people)
        capture("new-creation-edit-pops-detail")
        visible("Next", in: people).tap()
        visible("Change icon").tap()
        _ = visible("Audience icon Code")
        capture("new-native-icon-cloud")
        visible("Audience icon Heart").tap()
        capture("new-icon-heart-selected")
        for name in ["Replies", "Home", "Car", "Car", "Members", "Person"] {
            visible("Change icon").tap()
            visible("Audience icon " + name).tap()
        }
        capture("visual-icon-cycling-stable")
        visible("Save list").tap()
        _ = visible("Post")
        visible("Post").tap()
        visible("My Story", timeout: 45).tap()
        visible("storyAudienceSwitcher").tap()
        let sheet = app.otherElements["storyAudienceSheet"]
        _ = visible("Create List", in: sheet)
        capture("new-partial-viewer-sheet")
        print("PHYSICAL_CORNER_REVIEW_READY")
        visible("Select Everyone", in: sheet).tap()
        let move = app.alerts.firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: 10))
        XCTAssertTrue(move.staticTexts["Move to Everyone?"].exists)
        XCTAssertTrue(move.staticTexts["People in Weekend plans will no longer see this story"].exists)
        capture("visual-blue-move-alert")
        move.buttons["Cancel"].tap()
        XCTAssertTrue(visible("Weekend plans", in: sheet).isSelected)
        visible("Select Everyone", in: sheet).tap()
        app.alerts.firstMatch.buttons["Move"].tap()
        _ = visible("storyAudienceSwitcher")
        capture("new-moved-story")
        visible("storyAudienceSwitcher").tap()
        visible("Weekend plans", in: sheet).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        capture("new-viewer-detail-without-sheet")
        visible("Edit people").tap()
        _ = visible("Save List", in: people)
        visible("Sonya Litvinova", in: people).tap()
        visible("Save List", in: people).tap()
        _ = visible("Save list")
        visible("Save list").tap()
        _ = visible("storyAudienceSwitcher")
        XCTAssertFalse(sheet.exists)
        visible("storyAudienceSwitcher").tap()
        visible("Weekend plans", in: sheet).tap()
        visible("Delete List").tap()
        let deletion = app.alerts.firstMatch
        XCTAssertTrue(deletion.waitForExistence(timeout: 10))
        XCTAssertTrue(deletion.staticTexts["Delete Weekend plans?"].exists)
        XCTAssertTrue(deletion.staticTexts["Stories you posted to this list will become visible to Everyone"].exists)
        capture("new-delete-list-confirmation")
        deletion.buttons["Cancel"].tap()
        visible("Delete List").tap()
        app.alerts.firstMatch.buttons["Delete"].tap()
        _ = visible("storyAudienceSwitcher")
    }
    func testFigmaDefaultSevenEightAudienceThreshold() throws {
        visible("Next", timeout: 90).tap()
        func create(_ name: String, published: Bool = false) {
            visible("Create List").tap()
            let people = app.otherElements["storyAudiencePeopleScreen"]
            visible("Marina", in: people).tap()
            visible("Next", in: people).tap()
            let field = app.textFields["storyAudienceName"]
            XCTAssertTrue(field.waitForExistence(timeout: 15))
            field.tap(); field.typeText(name + "\n")
            visible("Save list").tap()
            if published { _ = visible("storyAudienceSwitcher") }
            else { XCTAssertTrue(visible(name).isSelected) }
            capture("new-threshold-created-" + name.replacingOccurrences(of: " ", with: "-"))
        }
        for index in 1 ... 4 { create("Circle \(index)") }
        visible("Post").tap()
        visible("My Story", timeout: 45).tap()
        visible("storyAudienceSwitcher").tap()
        let sheet = app.otherElements["storyAudienceSheet"]
        let partialTop = visible("Close", in: sheet).frame.minY
        XCTAssertGreaterThan(partialTop, 90)
        capture("new-seven-audiences-partial")
        create("Circle 5", published: true)
        _ = visible("storyAudienceSwitcher")
        visible("storyAudienceSwitcher").tap()
        let fullTop = visible("Close", in: sheet).frame.minY
        XCTAssertLessThan(fullTop, partialTop)
        capture("new-eight-audiences-full")
        visible("Circle 5", in: sheet).tap()
        let field = app.textFields["storyAudienceName"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        capture("new-full-sheet-horizontal-detail")
        visible("Back").tap()
        _ = visible("Create List", in: sheet)
    }
    func testFigmaDefaultRefinements() throws {
        visible("Next", timeout: 90).tap()
        _ = visible("Create List", timeout: 30)
        capture("revision-sheet-rest")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.13))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.23)), withVelocity: XCUIGestureVelocity(rawValue: 85), thenHoldForDuration: 0.2)
        capture("revision-sheet-drag-cancelled")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.13)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)), withVelocity: XCUIGestureVelocity(rawValue: 160), thenHoldForDuration: 0.1)
        visible("Next").tap()
        visible("Create List").tap()
        let people = app.otherElements["storyAudiencePeopleScreen"]
        _ = visible("Deselect All", in: people)
        capture("revision-people-empty")
        for person in ["Sonya Litvinova", "Marina", "daria", "Egor Gusev", "Rita PM"] { visible(person, in: people).tap() }
        capture("revision-people-selected")
        visible("Remove Pepe", in: people).tap()
        let removedToken = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: people.buttons["Remove Pepe"])
        wait(for: [removedToken], timeout: 5)
        visible("daria", in: people).tap()
        let headerY = visible("Deselect All", in: people).frame.minY
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.75)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.41)))
        XCTAssertEqual(visible("Deselect All", in: people).frame.minY, headerY, accuracy: 1)
        capture("revision-people-scrolled")
        visible("Next", in: people).tap()
        let field = app.textFields["storyAudienceName"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Weekend plans\n")
        capture("revision-detail-five")
        let member = app.otherElements["audienceMember-7880002"]
        XCTAssertTrue(member.waitForExistence(timeout: 10))
        member.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).press(forDuration: 0.1, thenDragTo: member.coordinate(withNormalizedOffset: CGVector(dx: 0.63, dy: 0.5)), withVelocity: XCUIGestureVelocity(rawValue: 140), thenHoldForDuration: 0.1)
        capture("revision-native-swipe-revealed")
        member.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        func removeGesture() {
            member.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).press(forDuration: 0.1, thenDragTo: member.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)), withVelocity: XCUIGestureVelocity(rawValue: 140), thenHoldForDuration: 0.1)
        }
        removeGesture()
        capture("revision-remove-confirmation")
        XCTAssertTrue(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.alerts.firstMatch.staticTexts["Sonya Litvinova will no longer see stories you post to this list"].exists)
        visible("Cancel").tap()
        XCTAssertTrue(member.exists)
        removeGesture()
        visible("Remove", timeout: 10).tap()
        XCTAssertFalse(member.exists)
        capture("revision-member-removed")
        visible("Save list").tap()
        let selected = app.buttons.matching(NSPredicate(format: "label == 'Weekend plans' AND selected == true")).firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 15))
        XCTAssertTrue(selected.isSelected)
        XCTAssertEqual(selected.value as? String, "4 people")
        visible("Post").tap()
        _ = visible("My Story", timeout: 45)
        capture("revision-populated-main")
        XCTAssertTrue((visible("Sonya Litvinova").value as? String ?? "").contains("Outgoing Message"))
        _ = visible("Marina")
        _ = visible("Alex Morgan")
        visible("My Story").tap()
        visible("4 Views").tap()
        _ = visible("Marina", timeout: 15)
        capture("revision-original-viewers")
        visible("Close").tap()
        visible("storyAudienceSwitcher").tap()
        _ = visible("Create List", timeout: 15)
        capture("revision-published-sheet")
        visible("Weekend plans").tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        capture("revision-published-detail")
        visible("Edit people").tap()
        let publishedPeople = app.otherElements["storyAudiencePeopleScreen"]
        _ = visible("Save List", in: publishedPeople)
        capture("revision-published-people")
        visible("Back", in: publishedPeople).tap()
        let returned = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: field)
        wait(for: [returned], timeout: 15)
        capture("revision-published-people-back")
    }
    func testFigmaDefaultAppearance() throws {
        visible("Next", timeout: 90).tap()
        _ = visible("Create List", timeout: 30)
        capture("figma-default-sheet")
        visible("Create List").tap()
        let people = app.otherElements["storyAudiencePeopleScreen"]
        for person in ["Sonya Litvinova", "Marina", "daria", "Egor Gusev", "Rita PM"] { visible(person, in: people).tap() }
        visible("Next", in: people).tap()
        let field = app.textFields["storyAudienceName"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.typeText("Product Team\n")
        capture("figma-detail-five-members")
        visible("Save list").tap()
        _ = visible("Product Team", timeout: 15)
        capture("figma-created-list-selected")
    }
    func testAudienceSheetAppearance() throws {
        try checkAudienceSheetScrollRegression()
        visible("Close", in: app.otherElements["storyAudienceSheet"]).tap()
        try testRefinedSheetPublishSmoke()
    }
    private func checkAudienceSheetScrollRegression() throws {
        visible("Next", timeout: 90).tap()
        let sheet = app.otherElements["storyAudienceSheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 20))
        visible("Select Everyone", in: sheet).tap()
        let initialProfileY = visible("Pepe", in: sheet).frame.minY
        capture("sheet-initial")
        sheet.swipeUp(); sheet.swipeUp(); sheet.swipeUp()
        let profile = sheet.descendants(matching: .any).matching(NSPredicate(format: "label == 'Save to My Profile'")).firstMatch
        XCTAssertTrue(profile.exists)
        capture("sheet-bottom")
        profile.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        capture("sheet-bottom-toggle-on")
        visible("Create List", in: sheet).tap()
        let people = app.otherElements["storyAudiencePeopleScreen"]
        _ = visible("Next", in: people)
        visible("Back", in: people).tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 15))
        for _ in 0..<4 {
            let profile = sheet.buttons.matching(NSPredicate(format: "label == 'daria'")).firstMatch
            if profile.exists {
                // Finish a slow content drag without overshooting into native modal dismissal.
                let delta = max(0, initialProfileY - profile.frame.minY)
                if delta > 1 {
                    let start = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                    start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: min(delta, 250))), withVelocity: .slow, thenHoldForDuration: 0.2)
                }
                break
            }
            sheet.swipeDown()
        }
        capture("sheet-top-after-scroll")
    }

    func testRefinedSheetPublishSmoke() throws {
        visible("Next", timeout: 90).tap()
        let sheet = app.otherElements["storyAudienceSheet"]
        visible("Select Everyone", in: sheet).tap()
        visible("Post", in: sheet).tap()
        visible("My Story", timeout: 45).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        _ = visible("storyAudienceSwitcher")
        visible("4 Views").tap()
        _ = visible("Sonya Litvinova")
        capture("sheet-publish-original-viewers")
        visible("Close").tap()
        visible("storyAudienceSwitcher").tap()
        XCTAssertTrue(app.otherElements["storyAudienceSheet"].waitForExistence(timeout: 15))
    }

    func testFigmaDefaultFinalPolish() throws {
        visible("Next", timeout: 90).tap()
        capture("polish-share-profile-avatar")
        visible("Create List").tap()
        let people = app.otherElements["storyAudiencePeopleScreen"]
        visible("Marina", in: people).tap()
        visible("Next", in: people).tap()
        let field = app.textFields["storyAudienceName"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Save list"].isEnabled)
        capture("polish-disabled-save")
        field.tap(); field.typeText("Weekend plans\n")
        for icon in ["Members", "Car", "Vine", "Verified"] {
            visible("Change icon").tap()
            visible("Audience icon " + icon).tap()
            capture("polish-icon-" + icon)
        }
        visible("Save list").tap()
        capture("polish-ready-to-publish")
        visible("Post").tap()
        _ = visible("My Story", timeout: 45)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Tap above to view stories")).firstMatch.exists)
        capture("polish-main-with-friend-stories")
        visible("My Story").tap()
        visible("storyAudienceSwitcher").tap()
        _ = visible("Create List")
        capture("polish-published-audiences")
    }
    func testFigmaDefaultAvatarRelaunch() throws {
        visible("Next", timeout: 90).tap()
        capture("polish-avatar-first-launch")
        app.terminate()
        app.launch()
        visible("Next", timeout: 90).tap()
        capture("polish-avatar-second-launch")
    }
    func testFigmaDefaultIconSurfaces() throws {
        visible("Next", timeout: 90).tap()
        capture("polish-builtins-row-28")
        visible("Close Friends").tap()
        visible("Marina").tap()
        visible("Save List").tap()
        _ = visible("Create List")
        visible("Create List").tap()
        let people = app.otherElements["storyAudiencePeopleScreen"]
        visible("Marina", in: people).tap()
        visible("Next", in: people).tap()
        let field = app.textFields["storyAudienceName"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.typeText("Icon review\n")
        for name in ["Person", "Members", "Replies", "Home", "Heart", "Work", "Book", "Location", "Car", "Lock", "Crown", "Fire", "Sound", "Vine", "Verified", "Code"] {
            visible("Change icon").tap()
            if name == "Person" { capture("polish-new-icon-cloud") }
            visible("Audience icon " + name).tap()
            capture("polish-hero-72-" + name)
        }
        let member = app.otherElements["audienceMember-7880003"]
        member.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).press(forDuration: 0.1, thenDragTo: member.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)), withVelocity: XCUIGestureVelocity(rawValue: 140), thenHoldForDuration: 0.1)
        let removal = app.alerts.firstMatch
        XCTAssertTrue(removal.waitForExistence(timeout: 10))
        XCTAssertTrue(removal.staticTexts["Remove person?"].exists)
        XCTAssertTrue(removal.staticTexts["Marina will no longer see stories you post to this list"].exists)
        capture("polish-neutral-member-removal")
        removal.buttons["Cancel"].tap()
        visible("Save list").tap()
        capture("polish-custom-row-28")
        visible("Post").tap()
        visible("My Story", timeout: 45).tap()
        func badge() -> XCUIElement {
            if !app.buttons["storyAudienceSwitcher"].isHittable {
                visible("My Story", timeout: 15).tap()
            }
            return visible("storyAudienceSwitcher")
        }
        let initial = badge().frame.size
        print("Unified capsule accessibility frame:", initial)
        capture("polish-custom-capsule-20")
        for title in ["Everyone", "My Contacts", "Close Friends", "Icon review"] {
            badge().tap()
            visible("Select " + title).tap()
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 10))
            alert.buttons["Move"].tap()
            let frame = badge().frame.size
            XCTAssertEqual(frame.width, initial.width, accuracy: 0.1)
            XCTAssertEqual(frame.height, initial.height, accuracy: 0.1)
            capture("polish-capsule-" + title.replacingOccurrences(of: " ", with: "-"))
        }
    }
    func testFigmaDefaultIconRewind() throws {
        visible("Next", timeout: 90).tap()
        visible("Create List").tap()
        let people = app.otherElements["storyAudiencePeopleScreen"]
        visible("Marina", in: people).tap()
        visible("Next", in: people).tap()
        let field = app.textFields["storyAudienceName"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.typeText("Team\n")
        visible("Save list").tap()
        visible("Post").tap()
        _ = visible("My Story", timeout: 45)
        app.terminate()
        app.launch()
        visible("Next", timeout: 90).tap()
        visible("Select Everyone").tap()
        visible("Post").tap()
        visible("My Story", timeout: 45).tap()
        let first = visible("storyAudienceSwitcher").frame.size
        capture("polish-rewind-first")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.45)).tap()
        let previous = visible("storyAudienceSwitcher").frame.size
        XCTAssertEqual(first.width, previous.width, accuracy: 0.1)
        XCTAssertEqual(first.height, previous.height, accuracy: 0.1)
        capture("polish-rewind-previous")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)).tap()
        let next = visible("storyAudienceSwitcher").frame.size
        XCTAssertEqual(first.width, next.width, accuracy: 0.1)
        XCTAssertEqual(first.height, next.height, accuracy: 0.1)
        capture("polish-rewind-next")
    }
}
