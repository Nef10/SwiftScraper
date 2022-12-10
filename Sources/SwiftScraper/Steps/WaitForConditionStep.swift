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
    private var params: [Any]
    private var paramsKeys: [String]

    private var startRunDate: Date?
    private weak var browser: Browser?
    private var model: JSON?
    private var completion: StepCompletionCallback?

    /// Initializer.
    ///
    /// - parameter assertionName: Name of JavaScript function that evaluates the conditions and returns a Boolean.
    /// - parameter timeoutInSeconds: The number of seconds before the step fails due to timeout.
    /// - parameter params: Parameters which will be passed to the JavaScript function.
    /// - parameter paramsKeys: Look up the values from the JSON model dictionary using these keys,
    ///   and pass them as the parameters to the JavaScript function. If provided, these are used instead of `params`.
    public init(assertionName: String, timeoutInSeconds: TimeInterval, params: Any..., paramsKeys: [String] = []) {
        self.assertionName = assertionName
        self.timeoutInSeconds = timeoutInSeconds
        self.params = params
        self.paramsKeys = paramsKeys
    }

    public func run(with browser: Browser, model: JSON, completion: @escaping StepCompletionCallback) {
        startRunDate = Date()
        self.browser = browser
        self.model = model
        self.completion = completion
        handleTimer()
    }

    func handleTimer() {
        guard let startRunDate = startRunDate, let browser = browser, let model = model, let completion = completion else {
             return
        }
        let params = getParameters()
        browser.runScript(functionName: assertionName, params: params) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let isOk):
                if isOk as? Bool ?? false {
                    self.reset()
                    completion(.proceed(model))
                } else {
                    if Date().timeIntervalSince(startRunDate) > self.timeoutInSeconds {
                        self.reset()
                        completion(.failure(SwiftScraperError.timeout, model))
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.refreshInterval) { [weak self] in
                            self?.handleTimer()
                        }
                    }
                }
            case .failure(let error):
                self.reset()
                completion(.failure(error, model))
            }
        }
    }

    private func getParameters() -> [Any] {
        let params: [Any]
        if paramsKeys.isEmpty {
            params = self.params
        } else {
            params = paramsKeys.map { model?[$0] ?? NSNull() }
        }
        return params
    }

    private func reset() {
        startRunDate = nil
        browser = nil
        model = nil
        completion = nil
    }
}
