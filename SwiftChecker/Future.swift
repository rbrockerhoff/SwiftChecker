//
//  Future.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 11/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.

import Foundation

/*	Functions and two Future classes to do easy asynchronous stuff.

	A Future is basically a way to reference a result that may take some time to
	obtain; while the final value is not 'resolved', you can add it to collections
	and do other things with the reference (other than accessing the value).

	In ObjC this is usually implemented as a proxy object which handles value
	access transparently, but Swift doesn't have proxy objects and can't subclass
	NSProxy either - all ObjC objects passed to Swift have to subclass NSObject.
*/

//	================================================================================
/**
	This generic class implements a simple Future.

	Use it like this:
		var aFuture: Future<someType> = Future { ...closure returning someType... }
	or
		var aFuture: Future<someType> = Future ( ...value of someType... )
	where the closure or value are supposed to take some time (over 1 ms), therefore
	worthwhile to be executed asynchronously. Type inference works, so the left-hand
	side on the examples above could usually just be written as
		var aFuture = Future...

	You can add aFuture to collections or pass it around. When you need the result,
	use either
		aFuture.value
	or
		aFuture as someType		(can also be an implicit cast)
	both will block if the Future hasn't resolved (happened) yet.

	You can also test if the Future has resolved with aFuture.resolved; this will not block.

	Notice that someType can be an optional, and then the closure/value may return nil to
	signal an error condition or timeout.
*/
class Future <T> {
	
//	--------------------------------------------------------------------------------
//	initializers
	
	///	This initializer creates and starts a Future using the argument closure.
	init(_ work: () -> T) {
		_run(work)
	}
	
	///	This initializer creates and starts a Future using the argument expression.
	init(_ work: @auto_closure ()-> T) {
		_run(work)
	}
	
//	--------------------------------------------------------------------------------
//	public properties

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
		let resolved = !_result.isEmpty
		_lock.unlock()
		return resolved
	}
	
//	--------------------------------------------------------------------------------
//	private properties
	
	///	This property  uses a combination mutex/lock to guarantee
	///	asynchronous access to the _result property.
	let _lock = NSCondition()
	
	/**	This property contains either an empty array or an array
		with a single member (the result) when the Future has resolved.
		
		My first impulse was to implement this as
		var _result: T
		but this demands a value to be assigned in init(), before the PerformAsync() call, and I
		could find no easy way to generate an empty generic T.
		
		Implementing it as an optional
		var _result: T? = nil
		causes a fatal compiler error "LLVM ERROR: unimplemented IRGen feature! non-fixed class layout"
		and, even if it worked, might be somewhat ambiguous/tricky to handle if T is itself optional.
		NOTE: this has been fixed in Xcode 6.0b3.
		
		So, implementing it as an array of T obviates the necessity of having an additional Bool to signal
		whether the Future has resolved.
		NOTE: new in Xcode 6.0b3 : syntax is now [ T ] instead of T[ ].
	 */
	var _result: [ T ] = [ ]
	
//	--------------------------------------------------------------------------------
//	private functions and methods
	
	///	This conversion function allows the Future to be downcast to its value.
	///	Note that both @conversion and __conversion() are currently unsupported!
	@conversion func __conversion() -> T {
		return value	// this will block until the Future is resolved
	}

	/**	This function is called by the initializers, avoiding code duplication.
	
		The argument closure is performed asynchronously and its value is captured.
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
	
}	// end of Future

//	================================================================================
/**	This Future subclass is useful for debugging and benchmarking.

	It allows you to measure the resolution time for the future and, if necessary,
	print it out for debugging.

	Use it like this:
		var aFuture: Future<someType> = Future("label") { ...closure returning someType... }
	or
		var aFuture: Future<someType> = Future ("label", ...value of someType... )
	where the label string can also be nil.

*/
class FutureDebug <T> : Future <T> {
	
	///	This internal property is used to measure the resolution time and contain the
	///	optional label.
	var _time: TimeStamp
	
	///	This computed property will return the resolution time in seconds.
	///	Note that it will block until the Future has resolved.
	var seconds: Double {
		_lock.lock()
		while _result.isEmpty {
			_lock.wait()
		}
		let e = _time.seconds
		_lock.unlock()
		return e
	}
	
	///	This computed property will return the optional label.
	var label: String? {
		return _time.label
	}
	
	///	This overrides the actual Future execution to measure the resolution time.
	///	As a convenience, it will print it out if a label has been assigned.
	override func _run(work: () -> T) {
		PerformAsync {
			let value = work()
			self._lock.lock()
			
			//	Freeze the TimeStamp to get the execution time and print it out if
			//	its label is present.
			let str = self._time.freeze()
			if self.label {
				PrintLN(str)
			}
			
			self._result = [ value ]
			self._lock.broadcast()
			self._lock.unlock()
		}
	}
	
	///	This initializer creates and starts a Future using the last argument closure.
	init(_ str: String?, _ work: () -> T) {
		_time = TimeStamp(str)
		super.init(work)
	}
	
	///	This initializer creates and starts a Future using the last argument expression.
	init(_ str: String?, _ work: @auto_closure ()-> T) {
		_time = TimeStamp(str)
		super.init(work)
	}

}	// end of FutureDebug

//	--------------------------------------------------------------------------------
/**
	The following convenience functions are for debugging only. For these to work, be sure to
	set "-D DEBUG" in "Other Swift Flags" for the Debug build in the Xcode project!

	They basically wrap and serialize the print() and println() functions to preserve
	sanity when invoking them from asynchronous tasks.

	They do nothing in non-Debug builds, so no need for #if DEBUG lines elsewhere - not even
	the arguments are evaluated, due to the @auto_closure trick.
*/

#if DEBUG
let printq = {	// global serial dispatch queue for print functions
		dispatch_queue_create("printq", DISPATCH_QUEUE_SERIAL)
	}()
#endif

func PrintLN <T> (object: @auto_closure () -> T) {
#if DEBUG
	dispatch_sync(printq) {
		println(object())
	}
#endif
}

func Print <T> (object: @auto_closure () -> T) {
#if DEBUG
	dispatch_sync(printq) {
		print(object())
	}
#endif
}

func PrintLN() {
#if DEBUG
	dispatch_sync(printq) {
		println()
	}
#endif
}

/**
	Accepts a closure to be performed on the next iteration of the main run loop;
	basically an equivalent of performSelectorOnMainThread: but with no object and
	waitUntilDone:NO.

	We might do dispatch_async(dispatch_get_main_queue(), work) here, but
	that may cut in front of other events waiting to be handled in the run loop.
	(Thanks to Kyle Sluder for the explanation.)
*/
func PerformOnMain(work: () -> Void) {
	CFRunLoopPerformBlock(NSRunLoop.mainRunLoop().getCFRunLoop(), kCFRunLoopCommonModes, work)
}

///	Accepts a closure to be performed asynchronously.
func PerformAsync(work: () -> Void) {
	//	Comment out the following line and substitute work() to check how the app would run
	//	without Futures/GCD.
	dispatch_async(dispatch_get_global_queue(0, 0), work)
}


