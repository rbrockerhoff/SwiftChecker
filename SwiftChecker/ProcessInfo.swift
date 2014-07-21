//
//  ProcessInfo.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 17/7/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

import Cocoa

//MARK: public class ProcessInfo
//	================================================================================
/**
	This class represents a running process and corresponds to one row in the NSTableView.
	It obtains and caches data displayed by the table.
*/
public class ProcessInfo: Comparable {		// Comparable implies Equatable
	
//	--------------------------------------------------------------------------------
//MARK:	initializers
	
	/**
		This single & only initializer does all the heavy lifting by getting data
		from the NSRunningApplication parameter.
	
		It uses Futures to get the bundle icon and to setup the displayed text, which will
		also contain the certificate summaries from the code signature.
	*/
	public init(_ app: NSRunningApplication) {
		
		//	Precalculate some values we'll need later on
		let name = app.localizedName
		let url = app.bundleURL
		let fpath = url.path.stringByDeletingLastPathComponent
		
		bundleName = name
		
		//	The icon may be read from disk, so making this a Future may save time. Still, the usual
		//	time to resolve is under 1 ms in my benchmarks.
		_icon = FutureDebug("\tIcon for \(name)") {
			var image: NSImage = app.icon
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
				result += " (32-bit)"
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
				if let entitlements = signature["entitlements-dict"] as? NSDictionary {
					if let sandbox = entitlements["com.apple.security.app-sandbox"] as? NSNumber {
						
						//	Even if the sandbox entitlement is present it may be 0 or NO
						if  sandbox.boolValue {
							result += ("sandboxed, ", styleBLUE)	// blue text to stand out
						}
					}
				}
				
				//	The certificates array may be empty or missing entirely.
				result += "signed "
				var haveCert = false
				
				//	Unfortunately, autoclosure of the right-hand side of && and || means you cannot do things like
				//	if let a = b && a.f() { … }. Hence the Bool flag.
				if let certificates = signature["certificates"] as? NSArray {
					if certificates.count > 0 {
						haveCert = true
						
						//	This gets the summaries for all certificates.
						let summaries = (certificates as Array).map {
							(cert) -> String in
							if let summary = GetCertSummary(cert) {
								return String(summary)	// CFString has to be converted
							}
							return "<?>"	// GetCertSummary() returned nil
						}
						//	Concatenating with commas is easy now
						result += join(", ",summaries)
					}
				}
				
				if (!haveCert) {	// signed but no certificates
					result += "without certificates"
				}
			} else {	// code signature missing
				result += ("unsigned", styleRED)	// red text to stand out
			}
			return result
		}
	}

//	--------------------------------------------------------------------------------
//MARK:	public properties

	///	This read-only property contains the localized bundle name (without extension).
	public let bundleName: String
	
	/**
		This is a computed property (so it must be var). It will get the future
		value from the _icon Future, meaning it will block while the icon
		is obtained.
	 */
	public var icon: NSImage {
		return _icon.value
	}
	
	/**
		This is a computed property (so it must be var). It will get the future
		value from the _text Future, meaning it will block while the text
		is obtained.
	 */
	public var text: NSAttributedString {
		return _text.value
	}

//	--------------------------------------------------------------------------------
//MARK:	private properties
	
///	This is the backing property for the (computed) icon property.
	private let _icon: Future <NSImage>
	
///	This is the backing property for the (computed) text property.
	private let _text: Future <NSAttributedString>

}	// end of ProcessInfo

//	================================================================================
/**
	The following operators, globals and functions are here because they're used or
	required by the ProcessInfo class.
*/

//	--------------------------------------------------------------------------------
//MARK:	public operators for comparing ProcessInfos
/*	must define < and == to conform to the Comparable and Equatable protocols.

	Here I use the bundleName in Finder order, convenient for sorting.
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

@assignment public func += (inout left: NSMutableAttributedString, right: String) {
	left.appendAttributedString(NSAttributedString(string: right, attributes: [ : ]))
}

@assignment public func += (inout left: NSMutableAttributedString, right: (str: String, att: NSDictionary)) {
	left.appendAttributedString(NSAttributedString(string: right.str, attributes: right.att))
}

//	Some preset style attributes for that last function. Note that these are Dictionaries of different
//	types, but we don't care as the += will cast them to NSDictionary.

public let styleRED = [NSForegroundColorAttributeName : NSColor.redColor()]
public let styleBLUE = [NSForegroundColorAttributeName : NSColor.blueColor()]
public let styleBOLD12 = [NSFontAttributeName : NSFont.boldSystemFontOfSize(12)]
public let styleNORM12 = [NSFontAttributeName : NSFont.systemFontOfSize(12)]

//	--------------------------------------------------------------------------------
//MARK: functions that get data from the Security framework

/**
	This function returns an Optional NSDictionary containing code signature data for the
	argument URL.
*/
private func GetCodeSignatureForURL(url: NSURL?) -> NSDictionary? {
	if let url = url {	// immediate unwrap if not nil, reuse the name
		
		//	SecStaticCodeCreateWithPath does an indirect return of SecStaticCode, so I need the
		//	Unmanaged<> container.
		var code: Unmanaged<SecStaticCode>? = nil
		//	See the odd SecCSFlags cast? This is because the header hasn't been annotated yet.
		var err = SecStaticCodeCreateWithPath(url, SecCSFlags(kSecCSDefaultFlags), &code)
		
		//	If the call succeeds, I immediately convert it to a managed object
		if err == 0 && code {
			let code = code!.takeRetainedValue()

			//	Same as above, the call will return an Unmanaged object...
			var dict: Unmanaged<CFDictionary>? = nil
			err = SecCodeCopySigningInformation(code, SecCSFlags(kSecCSSigningInformation), &dict)
			
			//	and if it succeeds, we return a managed object.
			if err == OSStatus(noErr) && dict {
				return dict!.takeRetainedValue()
			}
		}
	}
	return nil	// if anything untoward happens, we return nil.
}

/**
	This function returns an Optional String containing the summary for the
	parameter certificate.
 */
private func GetCertSummary(cert: AnyObject) -> CFString? {
	
	//	Note the brute-force cast which is equivalent to casting to id in ObjC.
	return SecCertificateCopySubjectSummary(reinterpretCast(cert)).takeRetainedValue()
}

