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

/*!
	Accepts a closure to be performed on the next iteration of the main run loop;
	basically an equivalent of performSelectorOnMainThread: but with no object and
	waitUntilDone:NO.
 */
func PerformOnMain(thing: () -> Void) {
//	We could just do dispatch_async(dispatch_get_main_queue(), thing) here, but
//	that would bypass other events waiting to be handled in the run loop.
	let loop = NSRunLoop.mainRunLoop().getCFRunLoop()
	CFRunLoopPerformBlock(loop!, kCFRunLoopCommonModes, thing)
}

/*!
	Accepts a closure to be performed asynchronously.
 */
func PerformAsync(thing: () -> Void) {
	dispatch_async(dispatch_get_global_queue(0, 0), thing)
}

/*!
	This generic class implements a simple Future. Use it like this:
		var aFuture: Future<someType> = Future { ...closure returning someType... }
	or
		var aFuture: Future<someType> = Future ( ...value of someType... )
	where the closure or value are supposed to take enough time, so worthwhile
	to be executed asynchronously.

	You can add aFuture to collections or pass it around. When you need the result,
	use aFuture.value(); this will block if the Future hasn't resolved (happened) yet.

	You can also test if the Future has resolved with aFuture.resolved(); this will not block.

	Notice that someType can be an optional, and the closure/value may return nil to
	signal an error condition or timeout.
 */
class Future <T> {

//	This property is for internal use only and uses a combination mutex/lock to guarantee
//	asynchronous access to the _result property.
	let _lock = NSCondition()

/*	This property is for internal use only and contains either an empty array or an array
	with a single member (the result) when the Future has resolved.
	
	My first impulse was to implement this as
		var _result: T
	but this demands a value to be assigned in init(), before the PerformAsync() call, and I
	could find no easy way to generate an empty generic T.
	
	Implementing it as an optional
		var _result: T? = nil
	causes a fatal compiler error "LLVM ERROR: unimplemented IRGen feature! non-fixed class layout"
	and, even if it worked, might be somewhat ambiguous/tricky to handle if T is itself optional.
	
	So, implementing it as an array T[] has two benefits: it works around the compiler error,
	and obviates the necessity of having an additional Bool to signal whether the Future has
	resolved.
 */
	var _result: T[] = []

/*	This function is for internal use only, avoiding code duplication.
	
	The argument closure is performed asynchronously and its value is captured.
	Access to _result is guarded by the mutex and other threads waiting are
	unblocked by the broadcast() call.
 */
	func _run(future: () -> T) {
		PerformAsync {
			let value = future()
			self._lock.lock()
			self._result = [ value ]	// note: value is put into an array!
			self._lock.broadcast()
			self._lock.unlock()
		}
	}

/*!
	This function creates and starts a Future using the argument closure.
 */
	init(future: () -> T) {
		_run(future)
	}
	
/*!
	This function creates and starts a Future using the argument expression.
 */
	init(_ future: @auto_closure ()-> T) {
		_run(future)
	}
	
/*!
	This function returns the actual Future value, and blocks while it is being resolved.
 */
	func value() -> T {
		_lock.lock()
		while _result.count < 1 {
			_lock.wait()
		}
		let r = _result[0]
		_lock.unlock()
		return r
	}
	
/*!
	This function tests if the Future has been resolved.
 */
	func resolved() -> Bool {
		_lock.lock()
		let r = _result.count > 0
		_lock.unlock()
		return r
	}
	
}
