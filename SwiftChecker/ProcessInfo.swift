//
//  ProcessInfo.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 17/7/14.
//  Copyright (c) 2014-2015 Rainer Brockerhoff. All rights reserved.
//

import Cocoa

//MARK: public class ProcessInfo
//	================================================================================
/**
# ProcessInfo
This class represents a running process and corresponds to one row in the `NSTableView`.

It obtains and caches data displayed by the table.
*/
public class ProcessInfo: Comparable {		// Comparable implies Equatable
	
//	--------------------------------------------------------------------------------
//MARK:	initializers
	
/**
	This single & only initializer does all the heavy lifting by getting data
	from the `NSRunningApplication` parameter.

	It uses Futures to get the bundle icon and to setup the displayed text, which will
	also contain the certificate summaries from the code signature.
*/
	public init(_ app: NSRunningApplication) {
		
		//	Fetch some values I'll need later on. 
		let name = app.localizedName!
		let url = app.bundleURL!
		let fpath = url.URLByDeletingLastPathComponent!.path!
		
		bundleName = name
		
		//	The icon may be read from disk, so making this a Future may save time. Still, the usual
		//	time to resolve is under 1 ms in my benchmarks.
		_icon = FutureDebug("\tIcon for \(name)") {
			let image = app.icon!
			image.size = NSSize(width: 64, height: 64)		// hardcoded to match the table column size
			return image
		}
		
		/*	The text is built up in sections and, if a signature is present, this will get the sandboxed
		attribute and the signing certificates from the signature and append the summaries.
		Reading signatures from disk means a Future is useful, here, too; the usual time to resolve is
		between 100 and 400 ms in my benchmarks.
		*/
		_text = FutureDebug("\tText for \(name)") {
			
			//	Start off with the localized bundle name in bold
			var result = NSMutableAttributedString(string: name, attributes: styleBOLD12)
			
			//	Add the architecture as a bonus value
			switch app.executableArchitecture {
			case NSBundleExecutableArchitectureI386:
				result += (" (32-bit)", styleRED)		// red text: most apps should be 64 by now
			case NSBundleExecutableArchitectureX86_64:
				result += " (64-bit)"
			default:
				break
			}
			
			//	Add the containing folder path — path components should be localized, perhaps?
			//	Check down below for the += operator for NSMutableAttributedStrings.
			result += (" in “\(fpath)”\n...", styleNORM12)
			
			//	GetCodeSignatureForURL() may return nil, an empty dictionary, or a dictionary with parts missing.
			if let signature = GetCodeSignatureForURL(url) {
				
				//	The entitlements dictionary may also be missing.
				if let entitlements = signature["entitlements-dict"] as? NSDictionary,
					sandbox = entitlements["com.apple.security.app-sandbox"] as? NSNumber {
						
					//	Even if the sandbox entitlement is present it may be 0 or NO
					if  sandbox.boolValue {
						result += ("sandboxed, ", styleBLUE)	// blue text to stand out
					}
				}
				
				result += "signed "

				//	The certificates array may be empty or missing entirely. Finally it's possible to cast
				//	directly to Array<SecCertificate> instead of going over CFTypeRef.
				let certificates = signature["certificates"] as? Array<SecCertificate>

				//	Using optional chaining here checks for both empty or missing.
				if certificates?.count > 0 {

					//	This gets the summaries for all certificates.
					let summaries = certificates!.map { (cert) -> String in
						return SecCertificateCopySubjectSummary(cert) as String
					}

					//	Concatenating with commas is easy now
					result += "by " + summaries.joinWithSeparator(", ")

				} else {	// signed but no certificates
					result += "without certificates"
				}

			} else {	// code signature missing
				result += ("unsigned", styleRED)	// red text to stand out; most processes should be signed
			}

			return result
		}
	}

//	--------------------------------------------------------------------------------
//MARK:	public properties

/**
This read-only property contains the localized bundle name (without extension).
*/
	public let bundleName: String
	
/**
This is a computed property (so it must be var). It will get the future
value from the `_icon` Future, meaning it will block while the icon is obtained.
 */
	var icon: NSImage {
		return _icon.value
	}
	
/**
This is a computed property (so it must be var). It will get the future
value from the `_text` Future, meaning it will block while the text is obtained.
 */
	var text: NSAttributedString {
		return _text.value
	}

//	--------------------------------------------------------------------------------
//MARK:	private properties
	
/**
This is the backing property for the (computed) icon property.
*/
	private let _icon: Future <NSImage>
	
/**
This is the backing property for the (computed) text property.
*/
	private let _text: Future <NSAttributedString>

}	// end of ProcessInfo

//	================================================================================
/**
	The following operators, globals and functions are here because they're used or
	required by the `ProcessInfo` class.
*/

//	--------------------------------------------------------------------------------
//MARK:	public operators for comparing `ProcessInfo`s
/**
must define < and == to conform to the `Comparable` and `Equatable` protocols.

Here I use the `bundleName` in Finder order, convenient for sorting.
*/
public func < (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {	// required by Comparable
	return lhs.bundleName.localizedStandardCompare(rhs.bundleName) == NSComparisonResult.OrderedAscending
}

public func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {	// required by Equatable and Comparable
	return lhs.bundleName.localizedStandardCompare(rhs.bundleName) == NSComparisonResult.OrderedSame
}

//	--------------------------------------------------------------------------------
//MARK:	public operators for appending a string to a NSMutableAttributedString.
/*
	var someString = NSMutableAttributedString()
	someString += "text" // will append "text" to the string
	someString += ("text", [NSForegroundColorAttributeName : NSColor.redColor()]) // will append red "text"

	+= is already used for appending to a mutable string, so this is a useful shortcut.

	Notice a useful feature in the second case: passing a tuple to an operator.
*/

/// The right-hand String is appended to the left-hand NSMutableString.
 public func += (inout left: NSMutableAttributedString, right: String) {
	left.appendAttributedString(NSAttributedString(string: right, attributes: [ : ]))
}

/// The right-hand tuple contains a String with an attribute NSDictionary to append
/// to the left-hand NSMutableString.

public func += (inout left: NSMutableAttributedString, right: (str: String, att: [String : AnyObject])) {
	left.appendAttributedString(NSAttributedString(string: right.str, attributes: right.att))
}

//	Some preset style attributes for that last function.

public let styleRED: [String : AnyObject] = [NSForegroundColorAttributeName : NSColor.redColor()]
public let styleBLUE: [String : AnyObject] = [NSForegroundColorAttributeName : NSColor.blueColor()]
public let styleBOLD12: [String : AnyObject] = [NSFontAttributeName : NSFont.boldSystemFontOfSize(12)]
public let styleNORM12: [String : AnyObject] = [NSFontAttributeName : NSFont.systemFontOfSize(12)]


//	--------------------------------------------------------------------------------
//MARK: functions that get data from the Security framework
 
/**
This function returns an Optional NSDictionary containing code signature data for the
argument file URL.
*/
private func GetCodeSignatureForURL(url: NSURL?) -> NSDictionary? {
	var result: NSDictionary? = nil
	if let url = url {	// immediate unwrap if not nil, reuse the name

		var code: SecStaticCode? = nil

		let err: OSStatus = SecStaticCodeCreateWithPath(url, SecCSFlags.DefaultFlags, &code)
		if err == OSStatus(noErr) && code != nil {

			var dict: CFDictionary? = nil

			let err = SecCodeCopySigningInformation(code!, SecCSFlags(rawValue: kSecCSSigningInformation), &dict)
			result = err == OSStatus(noErr) ? dict as NSDictionary? : nil
		}
	}
	return result	// if anything untoward happens, this will be nil.
}



