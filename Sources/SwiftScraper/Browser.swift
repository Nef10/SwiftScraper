//
//  Browser.swift
//  SwiftScraper
//
//  Created by Ken Ko on 21/04/2017.
//  Copyright © 2017 Ken Ko. All rights reserved.
//

import Foundation
import os
import WebKit

// MARK: - Types

/// The result of the browser navigation.
typealias NavigationResult = Result<Void, SwiftScraperError>

/// Invoked when the page navigation has completed or failed.
typealias NavigationCallback = (_ result: NavigationResult) -> Void

/// The result of some JavaScript execution.
///
/// If successful, it contains the response from the JavaScript;
/// If it failed, it contains the error.
typealias ScriptResponseResult = Result<Any?, SwiftScraperError>

/// Invoked when the asynchronous call to some JavaScript is completed, containing the response or error.
typealias ScriptResponseResultCallback = (_ result: ScriptResponseResult) -> Void

// MARK: - Browser

/// The browser used to perform the web scraping.
///
/// This class encapsulates the webview and its delegates, providing an closure based API.
public class Browser: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

    // MARK: - Constants

    private enum Constants {
        static let coreScript = "SwiftScraper"
        static let messageHandlerName = "swiftScraperResponseHandler"
    }

    // MARK: - Properties

    private let moduleName: String
    private let logger = Logger()
    /// The webview itself
    public private (set) var webView: WKWebView!
    private let userContentController = WKUserContentController()
    private var navigationCallback: NavigationCallback?
    private var asyncScriptCallback: ScriptResponseResultCallback?

    // MARK: - Setup

    /// Initialize the Browser object.
    ///
    /// - parameter moduleName: The name of the JavaScript module. By convention, the filename of the JavaScript file
    ///   is the same as the module name.
    /// - parameter scriptBundle: The bundle from which to load the JavaScript file. Defaults to the main bundle.
    /// - parameter customUserAgent: The custom user agent string (only works for iOS 9+).
    init(moduleName: String, scriptBundle: Bundle = Bundle.main, customUserAgent: String? = nil) throws {
        self.moduleName = moduleName
        super.init()
        try setupWebView(moduleName: moduleName, customUserAgent: customUserAgent, scriptBundle: scriptBundle)
    }

    private func setupWebView(moduleName: String, customUserAgent: String?, scriptBundle: Bundle) throws {

        let coreScriptURL = Bundle.module.path(forResource: Constants.coreScript, ofType: "js")
        guard let coreScriptContent = try? String(contentsOfFile: coreScriptURL!) else {
            throw SwiftScraperError.commonScriptNotFound
        }
        let coreScript = WKUserScript(source: coreScriptContent, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(coreScript)

        let moduleScriptURL = scriptBundle.path(forResource: moduleName, ofType: "js")
        guard let moduleScriptContent = try? String(contentsOfFile: moduleScriptURL!) else {
            throw SwiftScraperError.scriptNotFound(name: moduleName)
        }
        let moduleScript = WKUserScript(source: moduleScriptContent,
                                        injectionTime: .atDocumentEnd,
                                        forMainFrameOnly: true)
        userContentController.addUserScript(moduleScript)

        userContentController.add(self, name: Constants.messageHandlerName)

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController

        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = customUserAgent
    }

    // MARK: - WKNavigationDelegate

    /// Tells the delegate that navigation is complete.
    /// - Parameters:
    ///   - webView: The web view that loaded the content.
    ///   - navigation: The navigation object that finished.
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        callNavigationCompletion(result: .success(()))
    }

    /// Tells the delegate that an error occurred during the early navigation process.
    /// - Parameters:
    ///   - webView: The web view that called the delegate method.
    ///   - navigation: The navigation object for the operation. This object corresponds to a
    ///      WKNavigation object that WebKit returned when the load operation began. You use it
    ///      to track the progress of that operation.
    ///   - error: The error that occurred.
    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        logger.warning("didFailProvisionalNavigation: \(error.localizedDescription)")
        let navigationError = SwiftScraperError.navigationFailed(errorMessage: error.localizedDescription)
        callNavigationCompletion(result: .failure(navigationError))
    }

    /// Tells the delegate that an error occurred during navigation.
    /// - Parameters:
    ///   - webView: The web view that reported the error.
    ///   - navigation: The navigation object for the operation. This object corresponds to a WKNavigation object
    ///      that WebKit returned when the load operation began. You use it to track the progress of that operation.
    ///   - error: The error that occurred.
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.warning("didFailNavigation: \(error.localizedDescription)")
        let nsError = error as NSError
        if nsError.domain == "NSURLErrorDomain" && nsError.code == NSURLErrorCancelled {
            return
        }
        let navigationError = SwiftScraperError.navigationFailed(errorMessage: error.localizedDescription)
        callNavigationCompletion(result: .failure(navigationError))
    }

    private func callNavigationCompletion(result: NavigationResult) {
        guard let navigationCompletion = self.navigationCallback else {
            return
        }
        // Make a local copy of closure before setting to nil, to due async nature of this,
        // there is a timing issue if simply setting to nil after calling the completion.
        // This is because the completion is the code that triggers the next step.
        self.navigationCallback = nil
        navigationCompletion(result)
    }

    // MARK: - WKScriptMessageHandler

    /// Tells the handler that a webpage sent a script message.
    /// - Parameters:
    ///   - userContentController: The user content controller that delivered the message to your handler.
    ///   - message: An object that contains the message details.
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        logger.debug("WKScriptMessage didReceiveMessage")
        guard message.name == Constants.messageHandlerName else {
            logger.info("Ignoring message with name of \(message.name)")
            return
        }
        asyncScriptCallback?(.success(message.body))
    }

    // MARK: - API

    /// Insert the WebView at index 0 of the given parent view,
    /// using AutoLayout to pin all 4 sides to the parent.
    func insertIntoView(parent: PlatformView) {
        #if canImport(UIKit)
        parent.insertSubview(webView, at: 0)
        #else
        parent.addSubview(webView)
        #endif
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: parent.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: parent.bottomAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: parent.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: parent.trailingAnchor).isActive = true
    }

    /// Loads a page with the given path into the WebView.
    func load(path: String, completion: @escaping NavigationCallback) {
        self.navigationCallback = completion
        webView.load(URLRequest(url: URL(string: path)!))
    }

    /// Run some JavaScript with error handling and logging.
    func runScript(functionName: String, params: [Any] = [], completion: @escaping ScriptResponseResultCallback) {
        guard let script = try? JavaScriptGenerator.generateScript(moduleName: moduleName,
                                                                   functionName: functionName,
                                                                   params: params) else {
            completion(.failure(SwiftScraperError.parameterSerialization))
            return
        }
        logger.debug("script to run: \(script)")
        webView.evaluateJavaScript(script) { response, error in
            if let nsError = error as NSError?,
                nsError.domain == WKError.errorDomain,
                nsError.code == WKError.Code.javaScriptExceptionOccurred.rawValue {
                let jsErrorMessage = nsError.userInfo["WKJavaScriptExceptionMessage"] as? String
                                        ?? nsError.localizedDescription
                self.logger.warning("javaScriptExceptionOccurred error: \(jsErrorMessage)")
                completion(.failure(SwiftScraperError.javascriptError(errorMessage: jsErrorMessage)))
            } else if let error = error {
                self.logger.warning("javascript error: \(error.localizedDescription)")
                completion(.failure(SwiftScraperError.javascriptError(errorMessage: error.localizedDescription)))
            } else {
                self.logger.debug("javascript response: \(String(describing: response))")
                completion(.success(response))
            }
        }
    }

    /// Run some JavaScript that results in a page being loaded (i.e. navigation happens).
    func runPageChangeScript(functionName: String, params: [Any] = [], completion: @escaping NavigationCallback) {
        self.navigationCallback = completion
        runScript(functionName: functionName, params: params) { result in
            if case .failure(let error) = result {
                completion(.failure(error))
                self.navigationCallback = nil
            }
        }
    }

    /// Run JavaScript asynchronously - the completion is called when a script message is received back from JavaScript
    func runAsyncScript(functionName: String, params: [Any] = [], completion: @escaping ScriptResponseResultCallback) {
        self.asyncScriptCallback = completion
        runScript(functionName: functionName, params: params) { result in
            if case .failure = result {
                completion(result)
                self.asyncScriptCallback = nil
            }
        }
    }
}
