@testable import SwiftScraper
import XCTest

class OpenPageStepTests: StepRunnerCommonTests {

    func testOpenPageStep() throws {
        let exp = expectation(description: #function)
        let stepRunner = try makeStepRunner(steps: [TestHelper.openPageOneStep])
        stepRunner.run {
            exp.fulfill()
        }
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates, [.inProgress(index: 0), .success])
    }

    func testOpenPageStepWithoutAssertion() throws {
        let exp = expectation(description: #function)

        let step1 = OpenPageStep(path: Bundle.module.url(forResource: "page1", withExtension: "html")!.absoluteString)

        let step2 = ScriptStep(functionName: "assertPage1Title") { response, _ in
            XCTAssertEqual(response as? Bool, true)
            exp.fulfill()
            return .proceed
        }

        let stepRunner = try makeStepRunner(steps: [step1, step2])
        stepRunner.run()
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates, [.inProgress(index: 0), .inProgress(index: 1), .success])
    }

    func testOpenPageAssertionFailed() throws {
        let exp = expectation(description: #function)

        let step1 = OpenPageStep(path: Bundle.module.url(forResource: "page1", withExtension: "html")!.absoluteString,
                                 assertionName: "assertPage2Title")

        let stepRunner = try makeStepRunner(steps: [step1])
        stepRunner.run {
            exp.fulfill()
        }
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates, [.inProgress(index: 0), TestHelper.failureResult])
        assertErrorState(stepRunner.state, is: .contentUnexpected)
    }

    func testOpenPageStepFailed() throws {
        let exp = expectation(description: #function)

        let step1 = OpenPageStep(path: "http://qwerasdfzxcv")

        let stepRunner = try makeStepRunner(steps: [step1])
        stepRunner.run {
            exp.fulfill()
        }
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates, [.inProgress(index: 0), TestHelper.failureResult])
        assertErrorState(stepRunner.state,
                         is: .navigationFailed(errorMessage: "A server with the specified hostname could not be found."))
    }

}
