//
//  Future.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 11/6/14.
//  Copyright (c) 2014-2015 Rainer Brockerhoff. All rights reserved.

import Foundation

/**
Functions and some Future classes to do easy asynchronous stuff.

A Future is basically a way to reference a result that may take some time to
obtain; while the final value is not 'resolved', you can add it to collections
and do other things with the reference (other than accessing the value).

In ObjC this is usually implemented as a proxy object which handles value
access transparently, but Swift doesn't have proxy objects and can't subclass
`NSProxy` either - all ObjC objects passed to Swift have to subclass `NSObject`.
*/

//MARK: public class Future
//	================================================================================
/**
# Future
This generic class implements a simple Future.

Use it like this:
```swift
	var aFuture: Future<someType> = Future {
		...closure returning someType...
	}
```
where the closure is supposed to take some time (over 1 ms), therefore worthwhile to be executed
asynchronously.
Type inference works, so the left-hand side on the examples above could usually just be written as
```swift
	var aFuture = Future...
```
You can add `aFuture` to collections or pass it around. When you need the result, use
```swift
	aFuture.value
```
this will block if the `Future` hasn't resolved (happened) yet.

You can also test if the `Future` has resolved with `aFuture.resolved`; this will not block.

Notice that `someType` can be an optional, and then the closure/value may return nil to signal an error or timeout.
*/
public class Future <T> {

//	--------------------------------------------------------------------------------
//MARK:	initializers
	
///	This initializer creates and starts a `Future` using the argument closure.
	public init(_ work: () -> T) {
		_run(work)
	}
	
//	--------------------------------------------------------------------------------
//MARK:	public properties

/**
This computed property returns the actual `Future` value, and blocks while it is being resolved.
*/
	public var value: T {
		_lock.lock()
		while _result.isEmpty {
			_lock.wait()
		}
		let r = _result[0]
		_lock.unlock()
		return r
	}
	
/**
This computed property tests if the `Future` has been resolved.
*/
	public var resolved: Bool {
		_lock.lock()
		let resolved = !_result.isEmpty
		_lock.unlock()
		return resolved
	}
	
//	--------------------------------------------------------------------------------
//MARK:	private properties
	
/**
This property  uses a combination mutex/lock to guarantee asynchronous access to the `_result` property.
*/
	private let _lock = NSCondition()
	
/**
This property contains either an empty array or an array with a single member (the result) when the Future has resolved.
	
My first impulse was to implement this as
```swift
	var _result: T
```
but this demands a value to be assigned in `init()`, before the `PerformAsync()` call, and I could find no
easy way to generate an empty generic `T`.

Implementing it as an Optional
```swift
	var _result: T? = nil
```
caused a fatal compiler error "LLVM ERROR: unimplemented IRGen feature! non-fixed class layout"
and, even if it worked, might be somewhat ambiguous/tricky to handle if `T` is itself Optional.
*NOTE: this has been fixed in Xcode 6.0b3.*

So, implementing it as an `array` of `T` obviates the necessity of having an additional `Bool` to signal whether the `Future` has resolved.
*/
	var _result: [ T ] = [ ]
	
//	--------------------------------------------------------------------------------
//MARK:	private functions and methods
	
/**
This function is called by the initializer, making subclassing easier.

The argument closure is performed asynchronously and its value is captured. Access to `_result` is guarded
by the mutex and other threads waiting are unblocked by the `broadcast()` call.
*/
	private func _run(work: () -> T) {
		PerformAsync {
			let value = work()
			self._lock.lock()
			self._result = [ value ]	// note that value is wrapped inside an array!
			self._lock.broadcast()
			self._lock.unlock()
		}
	}
	
}	// end of Future

// MARK: public class FutureDebug
//	================================================================================
/**
# FutureDebug
This `Future` subclass is useful for debugging and benchmarking.

It allows you to measure the resolution time for the `Future` and, if necessary, print it out for debugging.

Use it like this:
```swift
	var aFuture: FutureDebug<someType> =
		FutureDebug("label") {
		...closure returning someType...
	}
```
where the `label` string can also be `nil`.
*/
public class FutureDebug <T> : Future <T> {
	
//	--------------------------------------------------------------------------------
//MARK:	initializers
	
///	This initializer creates and starts a `Future` using the last argument closure.
	public init(_ str: String?, _ work: () -> T) {
		_time = TimeStamp(str)
		super.init(work)
		_lock.name = str;
	}

//	--------------------------------------------------------------------------------
//MARK:	public properties
	
/**
This computed property will return the optional label.
*/
	public var label: String? {
		return _time.label
	}
	
/**
This computed property will return the resolution time in seconds, blocking until the `Future` has resolved.
*/
	public var seconds: Double {
		_lock.lock()
		while _result.isEmpty {
			_lock.wait()
		}
		let e = _time.seconds
		_lock.unlock()
		return e
	}

//	--------------------------------------------------------------------------------
//MARK:	private properties
	
/**
This internal property is used to measure the  resolutiontime and contain the optional label.
*/
	private var _time: TimeStamp
	
//	--------------------------------------------------------------------------------
//MARK:	private functions and methods
	
/**
This overrides the actual `Future` execution to measure the resolution time.

As a convenience, it will print it out if a label has been assigned.
*/
	private override func _run(work: () -> T) {
		PerformAsync {
			let value = work()
			self._lock.lock()
			
			//	Freeze the TimeStamp to get the execution time and print it out if
			//	its label is present.
			let str = self._time.freeze()
			if self.label != nil {
				Print(str)
			}
			
			self._result = [ value ]
			self._lock.broadcast()
			self._lock.unlock()
		}
	}
	
}	// end of FutureDebug

/// This private `enum` represents either a valid result value or a thrown error.
private enum Result<T> {
	case resolved(T)
	case error(ErrorType)
}

//MARK: public class FutureThrows
//	================================================================================
/**
# FutureThrows
This generic class implements a `Future` that can `throw` an `ErrorType` *(new to Swift 2)*.

Use it like this:
```swift
	var aFuture: FutureThrows<someType> =
		FutureThrows {
		...closure returning someType or throw...
	}
```
where the closure is supposed to take some time (over 1 ms), therefore worthwhile to be executed asynchronously.
Type inference works, so the left-hand side on the example above could usually just be written as
```swift
	var aFuture = FutureThrows...
```
You can add `aFuture` to collections or pass it around. When you need the result, use
```swift
	try let afv = aFuture.value()
```
followed by `catch`(es), or inside a `rethrows`; this will block if the `Future` hasn't resolved (happened) yet.

You can also test if the `Future` has resolved with `aFuture.resolved`; this will not block.

Notice that `someType` can be an optional, but returning `nil` should not be an error.
*/

public class FutureThrows <T> {

//	--------------------------------------------------------------------------------
//MARK:	initializers

///	This initializer creates and starts a `Future` using the argument closure.
	public init(_ work: () throws -> T) {
		_run(work)
	}
	
//	--------------------------------------------------------------------------------
//MARK:	public functions

/**
This function returns the actual `Future` value, and blocks while it is being resolved.

In Xcode 7b1 computed properties can't `throw` (yet), so this is a function for now.
*/
	public func value() throws -> T {
		_lock.lock()
		defer {		// the new defer syntax is handy since we have different return points
			_lock.unlock()
		}
		while (true) {
			guard let _result = _result else {	// use new guard statement to loop
				_lock.wait()
				continue
			}
			switch _result {
			case let .resolved(value):
				return value
			case let .error(error):
				throw error
			}
		}
	}
	
//	--------------------------------------------------------------------------------
//MARK:	public properties

/**
This computed property tests if the `Future` has been resolved.
*/
	public var resolved: Bool {
		_lock.lock()
		defer {		// again, the new defer syntax makes this shorter
			_lock.unlock()
		}
		return _result != nil ? true : false
	}
	
//	--------------------------------------------------------------------------------
//MARK:	private properties

/**
This property uses a combination mutex/lock to guarantee asynchronous access to the `_result` property.
*/
	private let _lock = NSCondition()
	
/**
This Optional property is either `nil`, while the `Future` is resolving, or a
`Result<T>`, which itself can represent a valid result value or a thrown error.
*/
	private var _result: Result<T>? = nil;
	
//	--------------------------------------------------------------------------------
//MARK:	private functions and methods

/**
This function is called by the initializer, making subclassing easier.

The argument closure is performed asynchronously and its value is captured.
Access to `_result` is guarded by the mutex and other threads waiting are unblocked by the `broadcast()` call.
*/
	private func _run(work: () throws -> T) {
		PerformAsync {
			let value: Result<T>
			do {
				try value = Result.resolved(work())
			} catch {
				value = Result.error(error)
			}
			self._lock.lock()
			self._result = value
			self._lock.broadcast()
			self._lock.unlock()
		}
	}
	
}	// end of FutureThrows

// MARK: public class FutureThrowsDebug
//	================================================================================
/**
# FutureThrowsDebug
This `FutureThrows` subclass is useful for debugging and benchmarking.

It allows you to measure the resolution time for the `Future` and, if necessary,
print it out for debugging.

Use it like this:
```swift
	var aFuture: FutureThrowsDebug<someType> =
		FutureThrowsDebug("label") {
		...closure returning someType or throw...
	}
```
where the `label` string can also be nil.
*/
public class FutureThrowsDebug <T> : FutureThrows <T> {
	
//	--------------------------------------------------------------------------------
//MARK:	initializers

///	This initializer creates and starts a `Future` using the last argument closure.
	public init(_ str: String?, _ work: () throws -> T) {
		_time = TimeStamp(str)
		super.init(work)
		_lock.name = str;
	}
	
//	--------------------------------------------------------------------------------
//MARK:	public properties
	
/**
This computed property will return the optional label.
*/
	public var label: String? {
		return _time.label
	}
	
/**
This computed property will return the resolution time in seconds. Note that it will block until the `Future` has resolved.
*/
	public var seconds: Double {
		_lock.lock()
		while _result == nil {
			_lock.wait()
		}
		let e = _time.seconds
		_lock.unlock()
		return e
	}
	
//	--------------------------------------------------------------------------------
//MARK:	private properties

/**
This internal property is used to measure the resolution time and contain the optional label.
*/
	private var _time: TimeStamp
	
//	--------------------------------------------------------------------------------
//MARK:	private functions and methods

/**
This overrides the actual `Future` execution to measure the resolution time.

As a convenience, it will print it out if a label has been assigned.
*/
	private override func _run(work: () throws -> T) {
		PerformAsync {
			let value: Result<T>
			do {
				try value = Result.resolved(work())
			} catch {
				value = Result.error(error)
			}
			self._lock.lock()
			
			//	Freeze the TimeStamp to get the execution time and print it out if
			//	its label is present.
			let str = self._time.freeze()
			if self.label != nil {
				Print(str)
			}
			
			self._result = value
			self._lock.broadcast()
			self._lock.unlock()
		}
	}
	
}	// end of FutureThrowsDebug

//	--------------------------------------------------------------------------------
//MARK: convenience debugging functions
/**
	The following convenience functions are for debugging only. For these to work, be sure to
	set "-D DEBUG" in "Other Swift Flags" for the Debug build in the Xcode project!

	They basically wrap and serialize the `print()` functions to preserve
	sanity when invoking them from asynchronous tasks.

	They do nothing in non-Debug builds, so no need for #if DEBUG lines elsewhere - not even
	the arguments are evaluated, due to the `@autoclosure` trick.
*/

#if DEBUG
private let _printq = {	// global serial dispatch queue for print functions
		dispatch_queue_create("printq", DISPATCH_QUEUE_SERIAL)
	}()
#endif

public func Print <T> (@autoclosure object: () -> T, appendNewline: Bool) {
#if DEBUG
	let temp: T = object()
	dispatch_sync(_printq) {
		print(temp, appendNewline: appendNewline)
	}
#endif
}

public func Print <T> (@autoclosure object: () -> T) {
#if DEBUG
	let temp: T = object()
	dispatch_sync(_printq) {
		print(temp)
	}
#endif
}

public func Print() {
#if DEBUG
	dispatch_sync(_printq) {
		print()
	}
#endif
}


//	--------------------------------------------------------------------------------
//MARK: convenience asynchronous functions
/**
Accepts a closure to be performed on the next iteration of the main run loop;
basically an equivalent of `performSelectorOnMainThread:` but with no `object` and
`waitUntilDone:NO`.

We might do `dispatch_async(dispatch_get_main_queue(), work)` here, but
that may cut in front of other events waiting to be handled in the run loop.
(Thanks to Kyle Sluder for the explanation.)
*/
public func PerformOnMain(work: () -> Void) {
	CFRunLoopPerformBlock(NSRunLoop.mainRunLoop().getCFRunLoop(), kCFRunLoopCommonModes, work)
}

/**
private concurrent dispatch queue
*/
private let _asyncq = {	// global concurrent dispatch queue for PerformAsync
	dispatch_queue_create("asyncq", DISPATCH_QUEUE_CONCURRENT)
	}()

/**
Accepts a closure to be performed asynchronously.
*/
public func PerformAsync(work: () -> Void) {
	//	Comment out the following line and substitute work() to check how the app would run
	//	without Futures/GCD.
	dispatch_async(_asyncq, work)
}

