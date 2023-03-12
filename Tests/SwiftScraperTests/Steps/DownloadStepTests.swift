@testable import SwiftScraper
import XCTest

class DownloadStepTests: StepRunnerCommonTests {

    var bundleURL: URL!
    var downloadURL: URL!

    override func setUpWithError() throws {
        bundleURL = Bundle.module.url(forResource: "page1", withExtension: "html")!
        let temporaryDir = NSTemporaryDirectory()
        let fileName = temporaryDir + "/" + UUID().description
        downloadURL = URL(fileURLWithPath: fileName)
        try FileManager.default.copyItem(at: bundleURL, to: downloadURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: downloadURL)
    }

    @available(iOS 14.5, macOS 11.3, *)
    func testDownloadStep() throws {


        let exp = expectation(description: #function)
        let exp1 = expectation(description: #function)
        let downloadStep = DownloadStep(url: downloadURL) { result, _ in
            XCTAssertEqual((result as! String), try? String(contentsOf: self.bundleURL, encoding: .utf8) ) // swiftlint:disable:this force_cast
            exp1.fulfill()
            return .proceed
        }
        let stepRunner = try makeStepRunner(steps: [downloadStep])
        stepRunner.run {
            exp.fulfill()
        }
        waitForExpectations()

        XCTAssertEqual(stepRunnerStates, [.inProgress(index: 0), .success])
    }

}
