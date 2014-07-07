//
//  Future.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 11/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.

import Foundation

/*	Functions and a Future class to do easy asynchronous stuff.

	A Future is basically a way to reference a result that may take some time to
	obtain; while the final value is not 'resolved', you can add it to collections
	and do other things with the reference (other than accessing the value).

	In ObjC this is usually implemented as a proxy object which handles value
	access transparently, but Swift doesn't have proxy objects and can't subclass
	NSProxy either - all ObjC objects passed to Swift have to subclass NSObject.
 */

/**
	@brief Accepts a closure to be performed on the next iteration of the main run loop;
	basically an equivalent of performSelectorOnMainThread: but with no object and
	waitUntilDone:NO.

	@discussion We might do dispatch_async(dispatch_get_main_queue(), work) here, but
	that may cut in front of other events waiting to be handled in the run loop.
	(Thanks to Kyle Sluder for the explanation.)
 */
func PerformOnMain(work: () -> Void) {
	CFRunLoopPerformBlock(NSRunLoop.mainRunLoop().getCFRunLoop(), kCFRunLoopCommonModes, work)
}

///	Accepts a closure to be performed asynchronously.
func PerformAsync(work: () -> Void) {
	dispatch_async(dispatch_get_global_queue(0, 0), work)
}

/**
	@brief This generic class implements a simple Future.

	@discussion Use it like this:
		var aFuture: Future<someType> = Future { ...closure returning someType... }
	or
		var aFuture: Future<someType> = Future ( ...value of someType... )
	where the closure or value are supposed to take enough time, so worthwhile
	to be executed asynchronously. Type inference works, so the left-hand side
	on the examples above could just be written as
		var aFuture = Future...

	You can add aFuture to collections or pass it around. When you need the result,
	use aFuture.value; this will block if the Future hasn't resolved (happened) yet.

	You can also test if the Future has resolved with aFuture.resolved; this will not block.

	Notice that someType can be an optional, and then the closure/value may return nil to
	signal an error condition or timeout.
 */
class Future<T> {

///	This property is for internal use only and uses a combination mutex/lock to guarantee
///	asynchronous access to the _result property.
	let _lock = NSCondition()

/**	@brief This property is for internal use only and contains either an empty array or an array
	with a single member (the result) when the Future has resolved.
	
	@discussion My first impulse was to implement this as
		var _result: T
	but this demands a value to be assigned in init(), before the PerformAsync() call, and I
	could find no easy way to generate an empty generic T.
	
	Implementing it as an optional
		var _result: T? = nil
	causes a fatal compiler error "LLVM ERROR: unimplemented IRGen feature! non-fixed class layout"
	and, even if it worked, might be somewhat ambiguous/tricky to handle if T is itself optional.
	NOTE: this has been fixed in Xcode 6.0b3.
	
	So, implementing it as an array [T] obviates the necessity of having an additional Bool to signal
	whether the Future has resolved.
	NOTE: new in Xcode 6.0b3 : syntax is now [T] instead of T[].
 */
	var _result: [T] = []

/**	@brief This function is for internal use only, avoiding code duplication.
	
	@discussion The argument closure is performed asynchronously and its value is captured.
	Access to _result is guarded by the mutex and other threads waiting are
	unblocked by the broadcast() call.
 */
	func _run(work: () -> T) {
		PerformAsync {
			let value = work()
			self._lock.lock()
			self._result = [ value ]	// note that value is wrapped inside an array!
			self._lock.broadcast()
			self._lock.unlock()
		}
	}

///	This function creates and starts a Future using the argument closure.
	init(work: () -> T) {
		_run(work)
	}
	
///	This function creates and starts a Future using the argument expression.
	init(_ work: @auto_closure ()-> T) {
		_run(work)
	}

//	The following two properties are the only external interface to a Future:	
	
///	This computed property returns the actual Future value, and blocks while it is being resolved.
	var value: T {
		_lock.lock()
		while _result.isEmpty {
			_lock.wait()
		}
		let r = _result[0]
		_lock.unlock()
		return r
	}
	
///	This computed property tests if the Future has been resolved.
	var resolved: Bool {
		_lock.lock()
		let empty = _result.isEmpty
		_lock.unlock()
		return !empty
	}
	
}



