//
//  AsyncProcessStep.swift
//
//
//  Created by Steffen Kötte on 2022-08-14.
//
import Foundation

// MARK: - Types

/// Handler that allows some custom action to be performed for `AsyncProcessStep`,
/// with the return value used to drive control flow of the steps.
///
/// - parameter model: The model JSON dictionary.
/// - returns: A tuple with the modified model and a `StepFlowResult` which allows control flow of the steps.
public typealias AsyncProcessStepHandler = (_ model: JSON, _ completion: @escaping (JSON, StepFlowResult) -> Void) -> Void

// MARK: - AsyncProcessStep

/// Step that performs some async processing, can update the model dictionary,
/// and can be used to drive control flow of the steps.
public class AsyncProcessStep: Step {

    private var handler: AsyncProcessStepHandler

    /// Initializer.
    ///
    /// - parameter handler: The action to perform in this step.
    public init(handler: @escaping AsyncProcessStepHandler) {
        self.handler = handler
    }

    public func run(with _: Browser, model: JSON, completion: @escaping StepCompletionCallback) {
        handler(model) { model, result in
            completion(result.convertToStepCompletionResult(with: model))
        }
    }
}
