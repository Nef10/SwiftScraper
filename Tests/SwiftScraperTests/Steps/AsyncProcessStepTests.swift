@testable import SwiftScraper
import XCTest

class AsyncProcessStepTests: StepRunnerCommonTests {

    private let doNotExecuteStep = AsyncProcessStep { model, completion in
        XCTFail("This step should not run")
        completion(model, .proceed)
    }

    func testAsyncProcessStep() throws {
        let exp = expectation(description: #function)

        // model is updated here
        let step2 = AsyncProcessStep { model, completion in
            var model = model
            model["number"] = 987.6
            model["bool"] = true
            model["text"] = "lorem"
            model["numArr"] = [1, 2, 3]
            model["obj"] = ["foo": "bar"]
            completion(model, .proceed)
        }

        let step3 = AsyncProcessStep { model, completion in
            self.assertModel(model)
            exp.fulfill()
            completion(model, .proceed)
        }

        let stepRunner = try makeStepRunner(steps: [TestHelper.openPageOneStep, step2, step3])
        stepRunner.run()
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates,
                       [.inProgress(index: 0), .inProgress(index: 1), .inProgress(index: 2), .success])
        self.assertModel(stepRunner.model)
    }

    func testAsyncProcessStepFinishEarly() throws {
        let exp = expectation(description: #function)

        let step2 = AsyncProcessStep { model, completion in
            var model = model
            model["step2"] = 123
            exp.fulfill()
            completion(model, .finish)
        }

        let stepRunner = try makeStepRunner(steps: [TestHelper.openPageOneStep, step2, doNotExecuteStep, doNotExecuteStep])
        stepRunner.run()
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates, [.inProgress(index: 0), .inProgress(index: 1), .success])
        XCTAssertEqual(stepRunner.model["step2"] as? Int, 123)
    }

    func testAsyncProcessStepFailEarly() throws {
        let exp = expectation(description: #function)

        let step2 = AsyncProcessStep { model, completion in
            var model = model
            model["step2"] = 123
            let error = NSError(domain: "StepRunnerTests", code: 12_345, userInfo: nil)
            exp.fulfill()
            completion(model, .failure(error)) // fail early
        }

        let stepRunner = try makeStepRunner(steps: [TestHelper.openPageOneStep, step2, doNotExecuteStep, doNotExecuteStep])
        stepRunner.run()
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates, [.inProgress(index: 0), .inProgress(index: 1), TestHelper.failureResult])
        if case .failure(let error) = stepRunner.state {
            // assert that error is correct
            XCTAssertEqual((error as NSError).domain, "StepRunnerTests")
            XCTAssertEqual((error as NSError).code, 12_345)

            // assert that model is correct
            XCTAssertEqual(stepRunner.model["step2"] as? Int, 123)
        } else {
            XCTFail("state should be failure, but was \(stepRunner.state)")
        }
    }

    func testAsyncProcessStepSkipStep() throws {
        let exp = expectation(description: #function)

        let step2 = AsyncProcessStep { model, completion in
            var model = model
            model["step2"] = 123
            completion(model, .jumpToStep(3))
        }

        let step4 = AsyncProcessStep { model, completion in
            var model = model
            model["step4"] = 345
            exp.fulfill()
            completion(model, .proceed)
        }

        let stepRunner = try makeStepRunner(steps: [TestHelper.openPageOneStep, step2, doNotExecuteStep, step4])
        stepRunner.run()
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates,
                       [.inProgress(index: 0), .inProgress(index: 1), .inProgress(index: 3), .success])
        XCTAssertEqual(stepRunner.model["step2"] as? Int, 123)
        XCTAssertEqual(stepRunner.model["step4"] as? Int, 345)
    }

    func testAsyncProcessStepSkipToInvalidStep() throws {
        let exp = expectation(description: #function)

        let step2 = AsyncProcessStep { model, completion in
            var model = model
            model["step2"] = 123
            completion(model, .jumpToStep(4))
        }
        let stepRunner = try makeStepRunner(steps: [TestHelper.openPageOneStep, step2, doNotExecuteStep, doNotExecuteStep])
        stepRunner.run {
            exp.fulfill()
        }
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates, [.inProgress(index: 0), .inProgress(index: 1), TestHelper.failureResult])
        XCTAssertEqual(stepRunner.model["step2"] as? Int, 123)
        assertErrorState(stepRunner.state, is: .incorrectStep)
    }

    func testAsyncProcessStepSkipStepToLoop() throws {
        var counter1 = 0, counter2 = 0

        let exp = expectation(description: #function)

        let step2 = AsyncProcessStep { model, completion in
            var model = model
            model["step2-\(counter1)"] = counter1
            counter1 += 1
            completion(model, .proceed)
        }

        let step3 = AsyncProcessStep { model, completion in
            var model = model
            model["step3-\(counter2)"] = counter2
            counter2 += 1
            // for the first to runs loop back to step2 again, for the third one continue as normal
            completion(model, counter2 == 3 ? .proceed : .jumpToStep(1))
        }

        let stepRunner = try makeStepRunner(steps: [TestHelper.openPageOneStep, step2, step3])
        stepRunner.run {
            // assert that the steps are called the correct number of times
            XCTAssertEqual(counter1, 3)
            XCTAssertEqual(counter2, 3)

            // asert the model can be updated
            XCTAssertEqual(stepRunner.model["step2-0"] as? Int, 0)
            XCTAssertEqual(stepRunner.model["step3-0"] as? Int, 0)
            XCTAssertEqual(stepRunner.model["step2-1"] as? Int, 1)
            XCTAssertEqual(stepRunner.model["step3-1"] as? Int, 1)
            XCTAssertEqual(stepRunner.model["step2-2"] as? Int, 2)
            XCTAssertEqual(stepRunner.model["step3-2"] as? Int, 2)
            exp.fulfill()
        }
        waitForExpectations()
    }

}
