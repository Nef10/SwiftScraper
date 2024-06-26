//
//  SwiftScraperError.swift
//  SwiftScraper
//
//  Created by Ken Ko on 21/04/2017.
//  Copyright © 2017 Ken Ko. All rights reserved.
//

import Foundation

/// Errors which can occurr during scraping
public enum SwiftScraperError: Error, LocalizedError, Equatable {

    /// Problem with serializing parameters to pass to the JavaScript.
    case parameterSerialization

    /// An assertion failed, the page contents was not what was expected.
    case contentUnexpected

    /// JavaScript error occurred when trying to process the page.
    case javascriptError(errorMessage: String)

    /// Page navigation failed with the given error.
    case navigationFailed(errorMessage: String)

    /// The step which was specified could not be found to be run, e.g. if an incorrect index was specified for
    /// `StepFlowResult.jumpToStep(Int)`.
    case incorrectStep

    /// Timeout occurred while waiting for a step to complete.
    case timeout

    /// Something went wrong with loading the common script, which is included in the package
    case commonScriptNotFound

    /// Something went wrong with loading the testing JavaScript file
    case scriptNotFound(name: String)

    /// Unable to read downloaded file from disk
    case couldNotReadDownloadedFile

    public var errorDescription: String? {
        switch self {
        case .parameterSerialization:
            return "Could not serialize the parameters to pass to the script"
        case .contentUnexpected:
            return "Something went wrong, the page contents was not what was expected"
        case .javascriptError(let errorMessage):
            return "A JavaScript error occurred: \(errorMessage)"
        case .navigationFailed(let errorMessage):
            return "Something went wrong when navigating to the page: \(errorMessage)"
        case .incorrectStep:
            return "An incorrect step was specified"
        case .timeout:
            return "Timeout occurred while waiting for a step to complete"
        case .commonScriptNotFound:
            return "Could not load SwiftScraper.js"
        case .scriptNotFound(let name):
            return "Could not load \(name)"
        case .couldNotReadDownloadedFile:
            return "Unable to read downloaded file"
        }
    }
}
