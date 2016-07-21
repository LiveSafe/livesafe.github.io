---
layout: post
title:  "Protocol-Oriented Networking in Swift with Alamofire"
date:   2016-07-24 18:00
author: fox
categories: ios
tags: swift, ios, networking
image: /assets/article_images/2016-07-21-protocol-oriented-networking-in-swift/traffic.png
image2: /assets/article_images/2016-07-21-protocol-oriented-networking-in-swift/traffic2.png
permalink: /protocol-oriented-networking-in-swift-with-alamofire/
comments: true
meta-description: "Protocol-Oriented Networking in Swift with Alamofire"
meta-keywords: "swift,alamofire,testing,protocol,technology,programming,ios"
---

## Dependency Injection in the Network Layer?

When we started building our iOS SDK, we noticed that we were constantly finding our stories/tasks blocked by back-end API development. We needed a way to build and test new functionality while the APIs we needed to consume were developed in parallel.

We decided to solve this problem by re-writing our networking framework using a protocol-oriented pattern. We figured this approach would allow us to choose either a live or mock network layer at the API call site, and would make writing unit tests a breeze.

One note before I dive into the code... We like the router patten commonly used with Alamofire, so you'll see evidence of that pattern throughout this post. If you aren't familiar with that pattern, you can read more about it [here](http://eliasbagley.github.io/json/api/alamofire/2015/09/25/making-network-requests-with-alamofire.html), [here](https://grokswift.com/router/), or [here](https://littlebitesofcocoa.com/93-creating-a-router-for-alamofire).

## It all Starts with a Protocol

Since we wanted a way to swap out the entire network layer implementation, we created a protocol that encapsulates the network layer.

{% highlight swift %}

protocol APIProxy {
  func makeNetworkCall(router: APIRouter,
                       completion: (response: APIResponse) -> ()) -> APIRequest
}

{% endhighlight %}

To make this approach work, we needed to write generic `APIRequest` and `APIResponse` objects for our `APIProxy` protocol to return. We won't go into the details of these structs here, but generally as we add proxy implementations, we write a new initializer that is specific to the `APIProxy` implementation's response. Here's an example for the Alamofire response object:

{% highlight swift %}

extension APIResponse {

  /// Convenience initializer for use with Alamofire Response objects
  init(response: Response<AnyObject, NSError>) {

    if let value = response.result.value {
      json = value
    }

    // Check if an error occurred and initialize the errorMessage property.
    if let error = response.result.error {
      errorMessage = error.description
      statusCode = 400
    }

    if let code =  response.response?.statusCode {
      statusCode = code
    }

  }
}
{% endhighlight %}

## Building on the Basic Framework

After we established the basis of our framework, we needed to actually implement two structs that conformed to `APIProxy`. For making live API calls, we implemented one proxy that used Alamofire.

{% highlight swift %}

struct AlamofireProxyImplementation: APIProxy {

  let manager = Alamofire.Manager.sharedInstance

  func makeCall(router: APIRouter, completion: (response: APIResponse) -> ()) -> APIRequest {

    let request =  manager.request(router).responseJSON { response in
      print(response.debugDescription)
      let wrappedResponse = APIResponse(response: response)
      completion(response: wrappedResponse)
    }

    return APIRequest(request: request)
  }
}

{% endhighlight %}

For unit tests, and building features in parallel with API development, we wrote a second proxy that returned mock response data from locally stored JSON files.

{% highlight swift %}

/// API test scenarios
enum APITestStatus {
  case Success
  case InvalidPermissions
  case TimeOut
  case NoNetwork
}

/// Mock implementation of APIProxy for use in testing
class MockProxyImplementation: APIProxy {

  var state: APITestStatus = .Success

  init(condition: APITestStatus) {
    state = condition
  }

  func makeCall(router: APIRouter, completion: (response: APIResponse) -> ()) -> APIRequest {
    return getProxyResponse(router, completion: completion)
  }

  private func getProxyResponse(router: APIRouter, completion: (response: APIResponse) -> ()) -> APIRequest {

    // Here you should switch on self.state and the router to create the specific response object
    let mockResponse = APIResponse()

    completion(response: mockResponse)
    let mockRequest = MockRequest(router: router)
    return APIRequest(request: mockRequest)
  }
}

{% endhighlight %}

## Pulling it all Together

With our two proxies implemented, all we had to do was inject the particular proxy we wanted at the API call site. There were a number of ways to achieve this, but we opted to write two `APIManager` structs.

{% highlight swift %}

protocol APIManager {
  var proxy: APIProxy { get }
}

struct LiveAPIManager: APIManager {
  var proxy: APIProxy = AlamofireProxyImplementation()
}

struct TestAPIManager: APIManager {

  var proxy: APIProxy = MockProxyImplementation(condition: .Success)

  init(testCondition: APITestStatus) {
    proxy = MockProxyImplementation(condition: testCondition)
  }
}

{% endhighlight %}

Now when we need to add a new API call to our framework, we just add a method and default implementation in an extension of our `APIManager` protocol. This way, both our managers can access and call the API using their respective proxy.

## Time to Start Making Calls

Since both of our `APIManager` implementations can make any of our API calls, we just have to choose which one we actually want to make the call. Just by adding `APIManager` as a parameter to a method which makes an API call, we achieve dependency injection of the network layer.

{% highlight swift %}

func getSomeDataForAViewController(fromManager manager: APIManager) {
  manager.someAPICall { (responseData) in
    // do something with the response data
  }
}

{% endhighlight %}


You can even go one step further, and set `LiveAPIManager` as the default value for the manager parameter. Then you only need to provide an `APIManager` while testing, or developing against a mock API.

{% highlight swift %}

func getSomeDataForAViewController(fromManager manager: APIManager = LiveAPIManager()) {
  manager.someAPICall { (responseData) in
    // do something with the response data
  }
}

{% endhighlight %}


## Final Thoughts

So through this approach we successfully achieved what we set out to build. We can now use mock response data to develop new features in parallel with the dependent APIs. When writing unit tests, we can mock responses by injecting a mock network layer at the API call site. As a bonus, we've minimized our architectural dependency on Alamofire (although not completely removed it due to our router pattern). Finally, we've given ourselves the ability to write new network layer implementations simply by conforming to the `APIProxy` protocol.

We're happy with what we've built, but we want to know what you think! Send me your thoughts, tips, or issues with this approach on [Twitter](http://www.twitter/com/nickffox)!

You can download our sample code [here](https://github.com/LiveSafe/lvsf-blog-code-samples/tree/master/ios/2016_07_25__protocol_oriented_networking_in_swift_with_alamofire).
