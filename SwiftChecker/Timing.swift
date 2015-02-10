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

//MARK: public struct TimeStamp
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
public struct TimeStamp : Printable {
	
//	--------------------------------------------------------------------------------
//MARK:	initializers
	
	///	Simplest initializer: current time, no label; absolute timestamp.
	public init() {
		absolute = true
		time = Int64(mach_absolute_time())
		label = nil
	}
	
	///	Initializer: current time, with label; absolute timestamp.
	public init(_ str: String?) {
		absolute = true
		time = Int64(mach_absolute_time())
		label = str
	}
	
	///	Initializer: time difference in seconds, label; relative timestamp.
	public init(_ start: Double, _ str: String?) {
		absolute = false
		time = Int64(start / TimeStamp._factor)
		label = str
	}
	
	///	Private initializer: flag, arbitrary time and label. You shouldn't need to use
	///	this directly.
	private init(_ absol: Bool, _ start: Int64, _ str: String?) {
		absolute = absol
		time = start
		label = str
	}
	
//	--------------------------------------------------------------------------------
//MARK:	public properties and methods
	
	/**	Returns the elapsed time in mach_absolute_time() units if absolute, nil if
		relative. You normally won't need to use that; either use the seconds
		property, or the description or age properties.
	*/
	public var elapsed: Int64? {
		return absolute ? Int64(mach_absolute_time()) - time : nil
	}
	
	///	Returns the TimeStamp value in seconds for relative TimeStamps. For absolute
	///	TimeStamps, returns the age instead.
	public var seconds: Double {
		let delta = absolute ? Int64(mach_absolute_time()) - time : time
		return Double(delta) * TimeStamp._factor
	}
	
	///	This is an optional label for the timestamp.
	//	Used only by the description and age properties.
	public var label: String?
	
	///	This Bool indicates whether the timestamp is absolute or relative.
	public let absolute: Bool
	
	///	Returns a printable description of the TimeStamp, useful for debugging.
	public var description: String {
		var prt = TimeStamp._format(absolute, time)
		if label != nil {
			prt = "\(label!): " + prt
		}
		return prt
	}
	
	///	Returns a printable description of the current age of the TimeStamp (returns
	///	description if it's relative).
	public var age: String {
		if let delta = elapsed {
			var prt = "\(TimeStamp._format(false, delta)) elapsed"
			if label != nil {
				prt = "\(label!): " + prt
			}
			return prt
		}
		return description
	}
	
	///	Call this to convert an absolute TimeStamp into a relative one, containing
	///	the elapsed time value. It also returns the new description as a convenience.
	public mutating func freeze() -> String {
		if (absolute) {
			self = TimeStamp(false, Int64(mach_absolute_time()) - time, label)
		}
		return description
	}

//	--------------------------------------------------------------------------------
//MARK:	private properties

	/**	This is the internal representation, same units as mach_absolute_time().
		You normally won't need to access it; either use the seconds property, or
		the description or age properties.
	*/
	private let time: Int64

//	--------------------------------------------------------------------------------
//MARK:	private functions and static values
	
	///	This static value is used to convert from internal units to seconds.
	private static let _factor: Double = {
		var tinfo = mach_timebase_info_data_t(numer:1, denom:1)
		mach_timebase_info(&tinfo)
		return Double(tinfo.numer) / (1e9 * Double(tinfo.denom))
		}()
	
	///	This function is used to generate a formatted string from a TimeStamp.
	private static func _format(absol: Bool, _ timeval: Int64) -> String {
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
//MARK:	public operators on TimeStamps

/**	This operator produces a new TimeStamp containing the difference between the
	two argument TimeStamps. This makes no sense if the left side is relative and the
	right absolute.
*/
public func - (left: TimeStamp, right: TimeStamp) -> TimeStamp! {
	if !left.absolute && right.absolute {
		return nil		// wrong combination, boom!
	}
	return TimeStamp(left.absolute != right.absolute, left.time - right.time, nil)
}

/**	This operator produces a new TimeStamp containing the sum of the two argument
	TimeStamps. This makes no sense if both sides are absolute.
*/
public func + (left: TimeStamp, right: TimeStamp) -> TimeStamp! {
	if left.absolute && right.absolute {
		return nil		// wrong combination, boom!
	}
	return TimeStamp(left.absolute != right.absolute, left.time + right.time, nil)
}

/**	This operator produces a new TimeStamp, subtracting the right value (in seconds)
	from the left TimeStamp. The TimeStamp type is conserved.
*/
public func - (left: TimeStamp, right: Double) -> TimeStamp {
	return TimeStamp(left.absolute, left.time - Int64(right / TimeStamp._factor), nil)
}

/**	This operator produces a new TimeStamp, adding the right value (in seconds)
	to the left TimeStamp. The TimeStamp type is conserved.
*/
func + (left: TimeStamp, right: Double) -> TimeStamp {
	return TimeStamp(left.absolute, left.time + Int64(right / TimeStamp._factor), nil)
}

//	================================================================================
//MARK:	useful functions for benchmarking a closure

public typealias BenchClosure = () -> Any?

/**
	This function accepts an optional label, a repetition count (which should be at
	least 1000 to be useful), and a closure to be benchmarked in serial; it produces a
	relative TimeStamp containing the average execution time for the closure.
	This makes no sense if the repetition count is < 1.
*/
public func BenchmarkSerial(comment: String?, times: UInt, work: BenchClosure) -> TimeStamp! {
	if (times < 1) {
		return nil		// zero repetitions, boom!
	}
	let total = _BenchmarkSerial(times, work)
	return TimeStamp(false, total, comment)
}

/// Same function with no label.
public func BenchmarkSerial(times: UInt, work: BenchClosure) -> TimeStamp! {
	return BenchmarkSerial(nil, times, work)
}

/**
	This function accepts an optional label, a repetition count (which should be a multiple of 10,
	and at least 100 to be useful), and a closure to be benchmarked in parallel; it produces a
	relative TimeStamp containing the average execution time for the closure.
	This makes no sense if the repetition count is < 1.
*/
public func BenchmarkParallel(comment: String?, times: UInt, work: BenchClosure) -> TimeStamp! {
	if (times < 1) {
		return nil		// zero, boom!
	}
	let total = _BenchmarkParallel(times, work)
	return TimeStamp(false, total, comment)
}

/// Same function with no label.
public func BenchmarkParallel(times: UInt, work: BenchClosure) -> TimeStamp! {
	return BenchmarkParallel(nil, times, work)
}

//	--------------------------------------------------------------------------------
//MARK:	various functions for benchmarking.

///	This utility function converts a time in seconds to an easier-to-read String.
public func SecsToStr(seconds: Double) -> String {
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
public func ReportTimingData() {
	PrintLN("Timing quantum = \(TimeStamp._format(false,1))")
	let overhead = BenchmarkSerial(1000) {
		return TimeStamp()
	}
	PrintLN("TimeStamp overhead = \(overhead)")
}

//	--------------------------------------------------------------------------------
//MARK:	private functions and values for benchmarking

///	This private function does the actual serial measurement.
private func _BenchmarkSerial(times: UInt, work: BenchClosure) -> Int64 {
	var total: Int64 = 0
	for _ in 1...times {
		let before = Int64(mach_absolute_time())
		let dummy = work()
		total += Int64(mach_absolute_time()) - before
	}
	return total / Int64(times)
}

///	private dispatch queue
private let _benchq = {	// global concurrent dispatch queue for BenchmarkParallel
	dispatch_queue_create("benchq", DISPATCH_QUEUE_CONCURRENT)
	}()

///	the stride count multiplier
private let _repeat: UInt = 10

///	This private function does the actual parallel measurement.
private func _BenchmarkParallel(times: UInt, work: BenchClosure) -> Int64 {
	let lock = NSCondition()
	var total: Int64 = 0
	let nt = min(1,times/_repeat)
	dispatch_apply(nt, _benchq) { (_) in
		let before = Int64(mach_absolute_time())
		for _ in 1..._repeat {
			let dummy = work()
		}
		let elapsed = Int64(mach_absolute_time()) - before
		lock.lock()
		total += elapsed
		lock.unlock()
	}
	return total / Int64(nt * _repeat)
}

