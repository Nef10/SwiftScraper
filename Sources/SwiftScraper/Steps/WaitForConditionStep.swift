//
//  WaitForConditionStep.swift
//  SwiftScraper
//
//  Created by Ken Ko on 28/04/2017.
//  Copyright © 2017 Ken Ko. All rights reserved.
//

import Foundation

/// Step that waits for condition to become true before proceeding,
/// failing if the condition is still false when timeout occurs.
public class WaitForConditionStep: Step {

    private enum Constants {
        static let refreshInterval: TimeInterval = 0.1
    }

    private var assertionName: String
    private var timeoutInSeconds: TimeInterval

    private var startRunDate: Date?
    private weak var browser: Browser?
    private var model: JSON?
    private var completion: StepCompletionCallback?

    /// Initializer.
    ///
    /// - parameter assertionName: Name of JavaScript function that evaluates the conditions and returns a Boolean.
    /// - parameter timeoutInSeconds: The number of seconds before the step fails due to timeout.
    public init(assertionName: String, timeoutInSeconds: TimeInterval) {
        self.assertionName = assertionName
        self.timeoutInSeconds = timeoutInSeconds
    }

    public func run(with browser: Browser, model: JSON, completion: @escaping StepCompletionCallback) {
        startRunDate = Date()
        self.browser = browser
        self.model = model
        self.completion = completion
        handleTimer()
    }

    func handleTimer() {
        guard let startRunDate = startRunDate,
            let browser = browser,
            let model = model,
            let completion = completion else { return }
        browser.runScript(functionName: assertionName) { [weak self] result in
            guard let this = self else {
                return
            }
            switch result {
            case .success(let isOk):
                if isOk as? Bool ?? false {
                    this.reset()
                    completion(.proceed(model))
                } else {
                    if Date().timeIntervalSince(startRunDate) > this.timeoutInSeconds {
                        this.reset()
                        completion(.failure(SwiftScraperError.timeout, model))
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.refreshInterval) { [weak this] in
                            guard let that = this else {
                                return
                            }
                            that.handleTimer()
                        }
                    }
                }
            case .failure(let error):
                this.reset()
                completion(.failure(error, model))
            }
        }
    }

    private func reset() {
        startRunDate = nil
        browser = nil
        model = nil
        completion = nil
    }
}
