//
//  DownloadStep.swift
//  SwiftScraper
//
//  Created by Steffen Kötte on 2023-03-11.
//

import Foundation
import WebKit

// MARK: - DownloadStep

/// Step that downloads a file from a given URL and returns the contents
///
/// The `StepFlowResult` returned by the `handler` can be used to drive control flow of the steps.
@available(iOS 14.5, macOS 11.3, *)
public class DownloadStep: NSObject, Step {

    private var url: URL
    private var destinationURL: URL!
    private var handler: ScriptStepHandler
    private var completion: StepCompletionCallback?
    private var model: JSON!

    /// Initializer.
    ///
    /// - parameter url: URL to download from
    /// - parameter handler: Callback function which returns the downloaded data, and passes the model JSON dictionary
    ///   for modification.
    public init(
        url: URL,
        handler: @escaping ScriptStepHandler
    ) {
        self.url = url
        self.handler = handler
    }

    public func run(with browser: Browser, model: JSON, completion: @escaping StepCompletionCallback) {
        self.completion = completion
        self.model = model
        browser.webView.startDownload(using: URLRequest(url: url)) { download in
            download.delegate = self
        }
    }

}

@available(iOS 14.5, macOS 11.3, *)
extension DownloadStep: WKDownloadDelegate {

    public func download(_: WKDownload, decideDestinationUsing _: URLResponse, suggestedFilename: String, completionHandler: (URL?) -> Void) {
        let temporaryDir = NSTemporaryDirectory()
        let fileName = temporaryDir + "/" + suggestedFilename + UUID().description
        let url = URL(fileURLWithPath: fileName)
        destinationURL = url
        completionHandler(url)
    }

    public func downloadDidFinish(_: WKDownload) {
        do {
            let text = try String(contentsOf: destinationURL, encoding: .utf8)
            try? FileManager.default.removeItem(at: destinationURL)
            var modelCopy: JSON = model
            let result = handler(text, &modelCopy)
            completion?(result.convertToStepCompletionResult(with: modelCopy))
        } catch {
            completion?(.failure(SwiftScraperError.couldNotReadDownloadedFile, model))
        }
    }

    public func download(_: WKDownload, didFailWithError error: Error, resumeData _: Data?) {
        completion?(.failure(error, model))
    }

}
