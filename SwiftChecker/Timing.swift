//
//  Timing.swift
//
//  Created by Rainer Brockerhoff on 7/7/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

import Foundation

/*	A struct and functions to do timing and benchmarking.

	The benchmarking functions aren't currently used in SwiftChecker but were
	useful during testing.
*/

//	================================================================================
/**
	This generic struct allows simple timing and timestamping.

	A TimeStamp can represent either a time interval (relative timestamp)
	or a time interval since the last reboot (absolute timestamp), both with good
	precision — nanoseconds on most modern Macs.

	The internal representation is based on the 64-bit value returned by the
	mach_absolute_time() function in <mach/mach_time.h>. Unlike that value, you can
	also construct negative values with the - operator.

	It can also contain an optional label.

	You can construct a TimeStamp in any of these ways:

	let t1 = TimeStamp()							// current time, no label
	let t2 = TimeStamp("Label")						// current time with label
	let t3 = TimeStamp(someInt64, optionalLabel)	// any values

	or by using the + and - operators, for instance:

	let delta = TimeStamp() - t2	// time since t2 was generated; label will be nil
	delta.label = "Difference"		// but you can set the label afterwards

*/
struct TimeStamp : Printable {
	
//	--------------------------------------------------------------------------------
//	initializers
	
	///	Simplest initializer: current time, no label; absolute timestamp.
	init() {
		absolute = true
		time = Int64(mach_absolute_time())
		label = nil
	}
	
	///	Initializer: current time, with label; absolute timestamp.
	init(_ str: String?) {
		absolute = true
		time = Int64(mach_absolute_time())
		label = str
	}
	
	///	Initializer: time difference in seconds, label; relative timestamp.
	init(_ start: Double, _ str: String?) {
		absolute = false
		time = Int64(start / TimeStamp._factor)
		label = str
	}
	
	///	Private initializer: flag, arbitrary time and label. You shouldn't need to use
	///	this directly.
	init(_ absol: Bool, _ start: Int64, _ str: String?) {
		absolute = absol
		time = start
		label = str
	}
	
//	--------------------------------------------------------------------------------
//	public properties and methods
	
	/**	Returns the elapsed time in mach_absolute_time() units if absolute, nil if
		relative. You normally won't need to use that; either use the seconds
		property, or the description or age properties.
	*/
	var elapsed: Int64? {
		return absolute ? Int64(mach_absolute_time()) - time : nil
	}
	
	///	Returns the TimeStamp value in seconds for relative TimeStamps. For absolute
	///	TimeStamps, returns the age instead.
	var seconds: Double {
		let delta = absolute ? Int64(mach_absolute_time()) - time : time
		return Double(delta) * TimeStamp._factor
	}
	
	///	This is an optional label for the timestamp.
	//	Used only by the description and age properties.
	var label: String?
	
	///	This Bool indicates whether the timestamp is absolute or relative.
	let absolute: Bool
	
	///	Returns a printable description of the TimeStamp, useful for debugging.
	var description: String {
		var prt = TimeStamp._format(absolute, time)
		if label {
			prt = "\(label!): " + prt
		}
		return prt
	}
	
	///	Returns a printable description of the current age of the TimeStamp (returns
	///	description if it's relative).
	var age: String {
		if let delta = elapsed {
			var prt = "\(TimeStamp._format(false, delta)) elapsed"
			if label {
				prt = "\(label!): " + prt
			}
			return prt
		}
		return description
	}
	
	///	Call this to convert an absolute TimeStamp into a relative one, containing
	///	the elapsed time value. It also returns the new description as a convenience.
	mutating func freeze() -> String {
		if (absolute) {
			self = TimeStamp(false, Int64(mach_absolute_time()) - time, label)
		}
		return description
	}

//	--------------------------------------------------------------------------------
//	private properties

	/**	This is the internal representation, same units as mach_absolute_time().
		You normally won't need to access it; either use the seconds property, or
		the description or age properties.
	*/
	let time: Int64

//	--------------------------------------------------------------------------------
//	private functions and static values
	
	///	This static value is used to convert from internal units to seconds.
	static let _factor: Double = {
		var tinfo = mach_timebase_info_data_t(numer:1, denom:1)
		mach_timebase_info(&tinfo)
		return Double(tinfo.numer) / (1e9 * Double(tinfo.denom))
		}()
	
	///	This function is used to generate a formatted string from a TimeStamp.
	static func _format(absol: Bool, _ timeval: Int64) -> String {
		if absol {
			let delta = Double(timeval - Int64(mach_absolute_time())) * TimeStamp._factor
			let date = NSDate(timeIntervalSinceNow: delta)
			let style = NSDateFormatterStyle.LongStyle
			return NSDateFormatter.localizedStringFromDate(date, dateStyle: style, timeStyle: style)
		}
		return SecsToStr(Double(timeval) * TimeStamp._factor)
	}

}	// end of TimeStamp

//	--------------------------------------------------------------------------------
//	Global operators on TimeStamps

/**	This operator produces a new TimeStamp containing the difference between the
	two argument TimeStamps. This makes no sense if the left side is relative and the
	right absolute.
*/
func - (left: TimeStamp, right: TimeStamp) -> TimeStamp! {
	if !left.absolute && right.absolute {
		return nil		// wrong combination, boom!
	}
	return TimeStamp(left.absolute ^ right.absolute, left.time - right.time, nil)
}

/**	This operator produces a new TimeStamp containing the sum of the two argument
	TimeStamps. This makes no sense if both sides are absolute.
*/
func + (left: TimeStamp, right: TimeStamp) -> TimeStamp! {
	if left.absolute && right.absolute {
		return nil		// wrong combination, boom!
	}
	return TimeStamp(left.absolute ^ right.absolute, left.time + right.time, nil)
}

/**	This operator produces a new TimeStamp, subtracting the right value (in seconds)
	from the left TimeStamp. The TimeStamp type is conserved.
*/
func - (left: TimeStamp, right: Double) -> TimeStamp {
	return TimeStamp(left.absolute, left.time - Int64(right / TimeStamp._factor), nil)
}

/**	This operator produces a new TimeStamp, adding the right value (in seconds)
	to the left TimeStamp. The TimeStamp type is conserved.
*/
func + (left: TimeStamp, right: Double) -> TimeStamp {
	return TimeStamp(left.absolute, left.time + Int64(right / TimeStamp._factor), nil)
}

//	================================================================================
//	Useful functions for benchmarking a closure

typealias BenchClosure = () -> Any?

/**
	This function accepts an optional label, a repetition count (which should be at
	least 1000 to be useful), and a closure to be benchmarked in serial; it produces a
	relative TimeStamp containing the average execution time for the closure.
	This makes no sense if the repetition count is < 1.
*/
func BenchmarkSerial(comment: String?, times: Int, work: BenchClosure) -> TimeStamp! {
	if (times < 1) {
		return nil		// zero or negative repetitions, boom!
	}
	let total = _BenchmarkSerial(times, work)
	return TimeStamp(false, total - _overheadSerial, comment)
}

/// Same function with no label.
func BenchmarkSerial(times: Int, work: BenchClosure) -> TimeStamp! {
	return BenchmarkSerial(nil, times, work)
}

/**
	This function accepts an optional label, a repetition count (which should be at
	least 100 to be useful), and a closure to be benchmarked in parallel; it produces a
	relative TimeStamp containing the average execution time for the closure.
	This makes no sense if the repetition count is < 1.
*/
func BenchmarkParallel(comment: String?, times: Int, work: BenchClosure) -> TimeStamp! {
	if (times < 1) {
		return nil		// zero or negative repetitions, boom!
	}
	let total = _BenchmarkParallel(times, work)
	return TimeStamp(false, total - _overheadParallel, comment)
}

/// Same function with no label.
func BenchmarkParallel(times: Int, work: BenchClosure) -> TimeStamp! {
	return BenchmarkParallel(nil, times, work)
}

//	--------------------------------------------------------------------------------
//	Various functions for benchmarking.

///	This utility function converts a time in seconds to an easier-to-read String.
func SecsToStr(seconds: Double) -> String {
	let magn = abs(seconds)
	if magn < 1e-6 {
		return "\(1e9 * seconds) ns"
	}
	if magn < 1e-3 {
		return "\(1e6 * seconds) µs"
	}
	if magn < 1 {
		return "\(1e3 * seconds) ms"
	}
	return "\(seconds) s"
}

///	This utility function reports internal overhead values.
func ReportTimingData() {
	PrintLN("Timing quantum = \(TimeStamp._format(false,1))")
	PrintLN("Parallel overhead = \(TimeStamp._format(false,_overheadParallel))")
	PrintLN("Serial overhead = \(TimeStamp._format(false,_overheadSerial))")
	let overhead = BenchmarkSerial(1000) {
		return TimeStamp()
	}
	PrintLN("TimeStamp overhead = \(overhead)")
}

//	--------------------------------------------------------------------------------
//	Various internal functions and values for benchmarking. Do not call directly.

///	This internal function does the actual serial measurement.
func _BenchmarkSerial(times: Int, work: BenchClosure) -> Int64 {
	var total: Int64 = 0
	for var i = 0; i < times; i++ {
		let before = Int64(mach_absolute_time())
		let dummy = work()
		total += Int64(mach_absolute_time()) - before
	}
	return total / Int64(times)
}

///	This internal function does the actual parallel measurement.
func _BenchmarkParallel(times: Int, work: BenchClosure) -> Int64 {
	let lock = NSCondition()
	var unresolved = times
	var total: Int64 = 0
	for var i = 0; i < times; i++ {
		dispatch_async(dispatch_get_global_queue(0, 0)) {
			let before = Int64(mach_absolute_time())
			let dummy = work()
			let elapsed = Int64(mach_absolute_time()) - before
			lock.lock()
			total += elapsed
			unresolved -= 1
			if unresolved == 0 {
				lock.broadcast()
			}
			lock.unlock()
		}
	}
	lock.lock()
	while unresolved > 0 {
		lock.wait()
	}
	lock.unlock()
	return total / Int64(times)
}

///	This internal value is used to estimate the extraneous timing overhead for
///	the Benchmark function. Don't mess with it. See Technical Q&A QA1398 for details.
let _overheadSerial: Int64 = {
	var times: Int = 10000		// seems a good value and wastes only a few ms
	return _BenchmarkSerial(times) {
			return mach_absolute_time()
		}
	}()

///	This internal value is used to estimate the extraneous timing overhead for
///	the BenchmarkParallel function. Don't mess with it. See Technical Q&A QA1398 for details.
let _overheadParallel: Int64 = {
	var times: Int = 1000		// seems a good value and wastes only a few ms
	return _BenchmarkParallel(times) {
			return mach_absolute_time()
		}
	}()

