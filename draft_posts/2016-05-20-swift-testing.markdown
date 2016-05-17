---
layout: post
title:  "Mocking Network Calls in Swift"
date:   2016-05-15 14:30
author: fox
categories: ios
tags: swift, ios, networking
image:
image2:
permalink: /mocking-network-calls-in-swift/
comments: true
meta-description: "Learn how to abstract away your network layer to easily mock network calls with Swift and Alamofire"
meta-keywords: "swift,alamofire,testing,protocol,technology,programming,ios"
---
#  Using Protocols to Stub out APIs

#### Why are we doing this?

When we add API endpoints, we don't always have the luxury of testing against a live endpoint during development. We needed a way to stub out particular API endpoints so we could build out new functionality in parallel with the API being build. Additionally, we wanted a way to write unit tests that that could be run completely offline. When we started building with Swift, we decided to begin building a new networking framework with Alamofire. This post will explain how we took "vanilla" Alamofire and wrapped it in protocols to create a more testable network layer.

One last thing before I start showing you code... We like the manager/router patten commonly used with AlamoFire, and we used that as the basis of our implementation. We're not going to cover that pattern here, but you can read more about it [here-FIXME](someUrl) or [here-FIXME](someOtherUrl) (these are the same resources we used when getting started with AlamoFire).

#### Protocols... Where it all begins

Like all good things in Swift, our approach starts with a protocol:


    protocol APIManager {
      var proxy: APIProxy { get }
      func makeCall(router: BaseRouter, completion: (LiveSafeApiResponse -> Void)) -> LiveSafeURLRequest
    }

    protocol APIProxy {
      func makeNetworkCall(router: URLRequestConvertible,
                           completion: LiveSafeApiResponse -> Void) -> LiveSafeURLRequest
    }

#### But what about Alamofire?

The APIProxy protocol represents the actual interaction with the network layer. This is where the network request is actually made. To get our network layer back in order, we just have to create an object that implements the APIProxy protocol.


    struct AlamofireProxyImplementation: APIProxy {

      let manager = Alamofire.Manager.sharedInstance

      func makeNetworkCall(router: URLRequestConvertible,
                           completion: LiveSafeApiResponse -> Void) -> LiveSafeURLRequest {
        let request =  manager.request(router).responseJSON { response in
          print(response.debugDescription)
          let lsResponse = LiveSafeApiResponse(response: response)
          completion(lsResponse)
        }

        return LiveSafeURLRequest(request: request)
      }
    }

You can see that this implementation simply hands off the router object to Alamofire and lets it do its thing. The completion we passed in is handed the response object, and things are working again. Hooray!

#### Ok, but you said something about mocks.

Now for the reason you're here... the mock implementation. I'll show you the code, then describe what's happening.


    enum APITestStatus {
      case Success
      case InvalidPermissions
      case TimeOut
      case NoNetwork
    }

    class MockProxyImplementation: APIProxy {

      var state: APITestStatus = .Success

      init(condition: APITestStatus) {
        state = condition
      }

      func makeNetworkCall(router: URLRequestConvertible, completion: LiveSafeApiResponse -> Void) -> LiveSafeURLRequest {

        var response = LiveSafeApiResponse()

        switch router {
        case is ChatRouter:
          response = getMockResponseForChatRouter(router as! ChatRouter)


        // case is SomeOtherRouter:
        //   response = getMockResponseForSomeOtherRouter(router as! SomeOtherRouter)


        default:
          print("INFO: Found router of unexpected type \(router)")
        }


        completion(response)

        let mockRequest = MockRequest(router: router)
        return LiveSafeURLRequest(request: mockRequest)
      }
    }

    // MARK: Chat Endpoint mock responses
    extension MockProxyImplementation {

      func getMockResponseForChatRouter(router: ChatRouter) -> LiveSafeApiResponse {

        var response = LiveSafeApiResponse()

        switch router.endpoint {
        case .SendChat:
          switch state {
          case .Success:
            // Read the response from our test JSON response file
            let json = JSONFileReader.getJSONNamed("GetChatHistorySuccess")
            response = LiveSafeApiResponse(status: 201, data: json)

          case .InvalidPermissions:
            response = LiveSafeApiResponse(status: 403, error: "Invalid Permissions")

          case .TimeOut:
            response = LiveSafeApiResponse(status: 504, error: "Network TimeOut")

          default:
            response = LiveSafeApiResponse(status: 404, error: "Unknown Case")
          }
        }

        return response
      }
    }


As you can see, we've written an enum to model the various network conditions we wish to test. The cases shown cover the basics, but you could easily add many more entries to this enum.

Next you'll notice that we've followed a similar pattern here in our mock implementation to the pattern we used in the `APIManager`. For each router we may need to mock responses for, we write an extension with a simple `getMockResponseFor____Router` method that generates our mock response from test JSON files we have created.

Lastly, a comment about MockProxyImplementation. Since we're migrating to Swift from Objective-C, we can't always do things in a perfectly "Swift-y" way. You may notice that MockProxyImplementation is a class instead of a struct. If you'll remember back to the start of the post, we said we wanted to be able to set the behavior of each call at the point the call is made. For example, during development we might want our GET chat call to succeed, but our post chat call to timeout. To make this happen we need to create a new MockProxyImplementation that will have the desired behavior, and sometimes we have to do that from Objective-C. Since you can't access a struct in Objective-C, this meant MockProxyImplementation had to be a class.

#### What do we do with these Proxies?

Now that we've implemented our two proxy objects, let's go back to the APIManager protocol. APIManager represents the overarching controller for all things webservice. This is the object that is responsible for knowing what call we're making, and how to parse the specific responses. Since it will just hand the information about the call we're making off to the APIProxy, we can implement the `makeCall` method in a protocol extension.

    extension APIManager {

      func makeCall(router: BaseRouter,
                    completion: (LiveSafeApiResponse -> Void)) -> LiveSafeURLRequest {

        return proxy.makeNetworkCall(router, completion: completion)
      }
    }

Now that we've fully defined the behavior of our APIManager protocol, let's create some objects that conform to it!

    class LiveSafeAPIManager: NSObject, APIManager {
      var proxy: APIProxy = AlamofireProxyImplementation()
    }

    class TestAPIManager: LiveSafeAPIManager {

      override init() {
        super.init()
        proxy = MockProxyImplementation(condition: .Success)
      }

      init(testCondition: APITestStatus) {
        super.init()
        self.proxy = MockProxyImplementation(condition: testCondition)
      }

    }

These implementations of `APIManager` are another perfect example of an Objective-C limitation. Since methods declared in protocol extensions aren't visible in Objective-C ([SEE THIS]()), we can't write all of our convenience webservice methods in an extension of `APIManager`. Instead, we've opted to make `TestAPIManager` extend `LiveSafeAPIManager`, and we write all of those methods in an extension of `LiveSafeAPIManager`. Following the chat example we've been using, here's what that looks like.

    extension LiveSafeAPIManager {

      public func getChatHistoryForTip(tip: LSTip,
                                       filters: APIFilters? = nil,
                                       success:(messages: [LSChat]) -> (),
                                       fail: (error: LSError) -> ()) -> LiveSafeURLRequest {

        let router = ChatRouter(endpoint:.GetChatHistory(tip: tip))
        if let unwrappedFilters = filters {
          router.filters = unwrappedFilters
        }

        return makeCall(router, completion: { response in
          if response.isSuccess {

            // Map JSON to objects, error checking, etc...
            success(messages: chatMessages)

          } else {

            // Create error object, and log information related to
            // the failure to assist during debugging
            fail(error: error)
          }
        })

      }

    }

#### Showtime... Actually Using It

Now that we've implemented both managers, and have successfully stubbed out the calls to `getChatHistoryForTip`, here is how we would make the call to the real endpoint in our code.

    let tip = LSTip()
    let manager = LiveSafeAPIManager()
    let request = manager.getChatHistoryForTip(tip, success: { messages in
        // Handle success
      }) { (error) in
        // Handle Failure
    }

To stub out the response instead, we simply change one line.

    let tip = LSTip()
    **let manager = TestAPIManager(testCondition: .Success)**
    let request = manager.getChatHistoryForTip(tip, success: { messages in
        // Handle success
      }) { (error) in
        // Handle Failure
    }

And there you have it. Any service call can be configured to return a mock response on a per-call basis. We've successfully wrapped our network layer with a well-defined interface so that we can now easily write unit tests for both request generation, and response handling.


Follow me on [Twitter](http://www.twitter/com/nickffox), and let me know what you think of this approach!
