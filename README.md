# SwiftScraper

[![CI Status](https://github.com/Nef10/SwiftScraper/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftScraper/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftScraper/badge.svg)](https://nef10.github.io/SwiftScraper/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftScraper)](https://github.com/Nef10/SwiftScraper/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftScraper?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftScraper/releases) ![platforms supported: macOS | iOS](https://img.shields.io/badge/platform-macOS%20%7C%20iOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

Web scraping library for Swift. This is a fork of [cweatureapps/SwiftScraper](https://github.com/cweatureapps/SwiftScraper), to offer the library as swift package.

# Overview

This framework provides a simple way to declaratively define a series of steps in Swift that represent how to scrape a web site, allowing the app to read this web page data.

# Features

* Declarative API - clearly define the steps to run and avoid the spaghetti 🍝 code that comes with using the WebView and the delegate pattern
* Custom JavaScript integration -  Simple integration with custom JavaScript to perform complicated scraping, using the language of the web to process the web page
* Perform custom processing at each step
* Passing data between steps
* Control flow to determine which step to run next, allowing basic conditionals and loops


# Tutorial

In this tutorial, we'll cover the basic usage of this framework by performing a Google search.

## Add package via Swift Package Manager

Add this dependency to your `Package.swift` file:
```swift
.package(url: "https://github.com/Nef10/SwiftScraper.git", .exact("X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*

## JavaScript setup

By convention, all the steps will use the functions exposed in a single module which is defined in a single JavaScript file.

For this exercise, create a new file called `GoogleSearch.js`.

Start by creating the blank JavaScript module structure, making sure the module name is the same as the file name:

```javascript
var GoogleSearch = (function() {
    return {
    };
})()
```

## Loading a web page

Create a new view controller.

Import the framework:

```swift
import SwiftScraper
```

In the view controller, we'll create a step and run it:

```swift
var stepRunner: StepRunner!

override func viewDidLoad() {
    super.viewDidLoad()
    let step1 = OpenPageStep(path: "https://www.google.com")
    stepRunner = StepRunner(moduleName: "GoogleSearch", steps: [step1])
    stepRunner.insertWebViewIntoView(parent: view)
    stepRunner.run()
}

```

When you run this, you will see a web view opening the Google home page.

> The web view typically needs to be have a visible frame size, because web sites often use responsive breakpoints and will even sometimes change the HTML structure based on the dimensions of the page.
>
> The `insertWebViewIntoView` method helps you to easily insert the web view into any `NSView` / `UIView` that you have, while automatically constraining it to the same size. It is up to you to set up the dimensions of the parent view, or you can even hide it where the user cannot see it.

## Check that the page loaded

We can add an assertion to run some JavaScript code when the page loads, to make sure the page that loaded is expected. We can do this by referencing a JavaScript function which is exposed by the module.

In the `GoogleSearch.js` file, add the following function which will just check the title of the page is correct.

```javascript
var GoogleSearch = (function() {
    function assertGoogleTitle() {
        return document.title == "Google";
    }
    return {
        assertGoogleTitle: assertGoogleTitle
    };
})()
```

In the view controller where you created the step, include the name of the assertion function:

```swift
let step1 = OpenPageStep(path: "https://www.google.com", assertionName: "assertGoogleTitle")
```

> The assertion function runs immediately when the page loads.
> Sometimes, what you are asserting may not be ready at the point when the page loads,
> as the website may modify the page asynchronously after loading.
> In this case check out the advanced usage to add a step which waits till the page is loaded.

## Observe progress of the run

You can observe the progress of the execution by adding a `stateObserver` to the stepRunner.

```swift
    stepRunner.stateObservers.append { newValue in
        print("-----", newValue, "-----")
        switch newValue {
        case .inProgress(let index):
            print("About to run step at index", index)
        case .failure(let error):
            print("Failed: \(error.localizedDescription)")
        case .success:
            print("Finished successfully")
        default:
            break
        }
    }
    stepRunner.run()
```

## Run script that loads page

Let's now run some custom JavaScript to submit a Google search. This is the `PageChangeStep` which runs some JavaScript, which will result in a new page being loaded. When the page is loaded, it will proceed to the next step.

Firstly, in the `GoogleSearch.js` file, add the following 2 functions which perform the search, and exposes them in the module:

```javascript
var GoogleSearch = (function() {

    // ...

    function performSearch(searchText) {
        document.querySelector('input[type="text"], input[type="Search"]').value = searchText;
        document.forms[0].submit();
    }
    function assertSearchResultTitle() {
        return document.title == "SwiftScraper iOS - Google Search";
    }
    return {
        assertGoogleTitle: assertGoogleTitle,
        performSearch: performSearch,
        assertSearchResultTitle: assertSearchResultTitle
    };
})()
```

In the view controller, add step 2 which is the `PageChangeStep`, referencing the JavaScript functions you just implemented:

```swift
let step2 = PageChangeStep(functionName: "performSearch", params: "SwiftScraper iOS", assertionName: "assertSearchResultTitle")
```

Notice the `params` parameter in the initializer, which allows you to pass data to the JavaScript function.

Make sure to include this in the array of steps when you create the `StepRunner`:

```swift
stepRunner = StepRunner(moduleName: "GoogleSearch", steps: [step1, step2])
```

## Run script and process

We're at the last step - we can run a script to scrape the contents of the page. Add the following JavaScript function which will get the search results, and return an Array of JSON objects with the text and href of each link.

```javascript
var GoogleSearch = (function() {

    // ...

    function getSearchResults() {
        var headings = document.querySelectorAll('h3.r');
        return Array.prototype.slice.call(headings).map(function (h3) {
            return { 'text': h3.innerText, 'href': h3.childNodes[0].href };
        });
    }

    return {
        assertGoogleTitle: assertGoogleTitle,
        performSearch: performSearch,
        assertSearchResultTitle: assertSearchResultTitle,
        getSearchResults: getSearchResults
    };
})()
```

In the Swift code, add the 3rd step which is a `ScriptStep`, a step which runs a JavaScript function and returns the response that the function returns.

```swift
let step3 = ScriptStep(functionName: "getSearchResults") { response, _ in
    if let responseArray = response as? [JSON] {
        responseArray.forEach { json in
            if let text = json["text"], let href = json["href"] {
                print(text, "(", href, ")")
            }
        }
    }
    return .proceed
}
```

And make sure to include this in the array of steps when you create the `StepRunner`:

```swift
stepRunner = StepRunner(moduleName: "GoogleSearch", steps: [step1, step2, step3])
```

Run this. You should see the steps complete successfully, and print the search results to the console.

Congratulations!  You've finished the tutorial on the basic usage of this library! 🎉

# Advanced Usage

## Run script that returns data async

It is possible to run some JavaScript that does not return immediately, and wait for it to asynchronously call back the Swift code after some time has passed. For example, you may need to do something on the web page, poll for the operation to complete, and then pass the data back to Swift.

To pass data back to Swift world, call `SwiftScraper.postMessage()`, passing a single object that can be serialized back to a Swift object.

In this example, we'll do a Google image search, and then scroll down to the bottom. The infinite scroll pattern employed here will load more images when we do this, and we'll do a count of the images before and after the scroll.

```javascript
var GoogleSearch = (function() {

    // ...

    function scrollAndCountImages() {
        var firstCount = document.querySelectorAll('img').length;
        window.scrollTo(0, document.body.scrollHeight);
        setTimeout(function () {
            var secondCount = document.querySelectorAll('img').length;
            SwiftScraper.postMessage({'first': firstCount, 'second': secondCount});
        }, 2000);
    }

    return {
        assertGoogleTitle: assertGoogleTitle,
        performSearch: performSearch,
        assertSearchResultTitle: assertSearchResultTitle,
        getSearchResults: getSearchResults,
        scrollAndCountImages: scrollAndCountImages
    };
})()
```

> For those familiar with `WKWebView`, the `SwiftScraper.postMessage()` function is just an alias for
> `webkit.messageHandlers.swiftScraperResponseHandler.postMessage()`

In Swift, use the `AsyncScriptStep`, which is used in the same way as `ScriptStep`, with the difference being the handler is not called until `SwiftScraper.postMessage` is called. It is expected that the JavaScript function itself does not return anything.

```swift
let step1 = OpenPageStep(path: "https://www.google.com.au/search?tbm=isch")

let step2 = PageChangeStep(
    functionName: "performSearch",
    params: "ankylosaurus")

let step3 = AsyncScriptStep(functionName: "scrollAndCountImages") { response, _ in
    if let json = response as? JSON {
        if let first = json["first"], let second = json["second"] {
            print("first: ", first, "second: ", second)
        }
    }
    return .proceed
}
```

## Process Step
Use the `ProcessStep` when you need a step that requires some custom action to be performed.

```swift
let processStep = ProcessStep { model in
    // perform some custom action here
    return .proceed
}
```

Two main concepts to note here are:
* The `model` parameter, used for passing model data between steps
* The return value, which can be used for control flow

These concepts apply to the `ProcessStep`, `ScriptStep` and `AsyncScriptStep`. We'll explore them in the next two sections.

## Passing model data
The `ProcessStep`, `ScriptStep` and `AsyncScriptStep` all have a handler closure to perform processing, and these handlers all have a model parameter of type `inout JSON`. Modify this JSON dictionary to save data during one step, and then read it in another step.

Let's modify the `AsyncScriptStep` from the previous section to save the before and after counts to the dictionary.

```swift
let step3 = AsyncScriptStep(functionName: "scrollAndCountImages") { response, model in  // notice the model param
    if let json = response as? JSON {
        if let first = json["first"], let second = json["second"] {
            print("first: ", first, "second: ", second)

            // Save the data to the model dictionary
            model["first"] = first
            model["second"] = second
        }
    }
    return .proceed
}
```

## Control Flow

The return value is an enum which can be used for rudimentary control flow. We've seen `.proceed` which means to go to the next step. The `.jumpToStep(n)` allows you to jump to another step, either before or after the current step. This allows you to define loops (by jumping back) as well as conditionals (by jumping forward).

Let's continue the infinite scrolling image search example, and add a `ProcessStep` that will keep looping back to `step3` until the before count and after count are the same, meaning there are no more images on the page to load.

Add this step as the last step to run. When you run this, you should see the screen keep scrolling down until no more images can be found.

```swift
let conditionStep = ProcessStep { model in
    if let first = model["first"] as? Int,
        let second = model["second"] as? Int,
        first == second {
        return .proceed
    } else {
        return .jumpToStep(2) // This is a zero-based index, i.e. step3
    }
}
```

> This technique is most useful for repeating a sequence of steps.
> While it can also be used to model IF-THEN style conditionals, it is essentially a `GOTO` construct
> and can easily lead to unmaintainable spaghetti 🍝 steps.

You can also have an early exit from the steps. The return value of `.finish` will stop execution as a success, while `.failure(Error)` will stop execution with a failure.


## Wait Step
A step that waits for a set period of time.

```swift
let waitStep = WaitStep(waitTimeInSeconds: 0.5)
```

## Wait for Condition Step
This is a step that waits for a condition to become true before proceeding, or it will fail if the condition is still false when the timeout occurs.

In this example, the iOS code will repeatedly call the JavaScript function `testThatStuffIsReady`, proceeding as soon as it returns true, or failing with a timeout if it doesn't return true within 2 seconds.

```swift
let waitForConditionStep = WaitForConditionStep(
    assertionName: "testThatStuffIsReady",
    timeoutInSeconds: 2)
```

# List of Steps

Here is the full list of steps discussed above:

- `OpenPageStep` - Loads a page and optionally executes a JavaScript assertion function to see that the page loaded correctly
- `PageChangeStep` - Calls a JavaScript function which is expected to navigate to a different page. Optionally executes a JavaScript assertion function to see that the new page loaded correctly
- `ScriptStep` - Runs a JavaScript function and returns the return value
- `AsyncScriptStep` - Runs an asynchronous JavaScript function and returns the return value
- `ProcessStep` - Runs swift code, which allows you do execute actions outside the scraper or modify the control flow
- `WaitStep` - Waits a fixed number of seconds
- `WaitForConditionStep` - Repeatedly calls a JavaScript function till it returns true (or times out)

# Examples

If you want to read more example code:

* [Swift code that performs a google text search](https://github.com/cweatureapps/SwiftScraper/blob/master/Example/SwiftScraperExample/TutorialViewController.swift)
* [Swift code that performs a google image search, and scrolls to count all images](https://github.com/cweatureapps/SwiftScraper/blob/master/Example/SwiftScraperExample/AdvancedTutorialViewController.swift)
* [The Javascript used in the above examples](https://github.com/cweatureapps/SwiftScraper/blob/master/Example/SwiftScraperExample/GoogleSearch.js)

# FAQ

***I'm getting the error: "An SSL error has occurred and a secure connection to the server cannot be made."***

App Transport Security (ATS) rules apply web views as well. If the website you are loading is not HTTPS, or uses outdated security protocols, macOS / iOS will refuse to load it.

The quick workaround is to disable ATS by putting the following setting in your `Info.plist`

```
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

However, at some point in the future, Apple may require that all apps submitted to the App Store support ATS.
