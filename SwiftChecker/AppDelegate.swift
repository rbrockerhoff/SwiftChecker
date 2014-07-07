//
//  AppDelegate.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 5/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

import Cocoa

/*	These two operators allow appending a string to a NSMutableAttributedString.

	var someString = NSMutableAttributedString()
	someString += "text" // will append "text" to the string
	someString += ("text", [NSForegroundColorAttributeName : NSColor.redColor()]) // will append red "text"

	+= is already used for appending to a mutable string, so this is a useful shortcut.

	Notice a useful feature in the second case: passing a tuple to an operator.
 */

@assignment func += (inout left: NSMutableAttributedString, right: String) {
	left.appendAttributedString(NSAttributedString(string: right, attributes: [:]))
}

@assignment func += (inout left: NSMutableAttributedString, right: (str: String, att: NSDictionary)) {
	left.appendAttributedString(NSAttributedString(string: right.str, attributes: right.att))
}

//	Some preset style attributes for that last function. Note that these are Dictionaries of different
//	types, but we don't care as the += will cast them to NSDictionary.
let styleRED = [NSForegroundColorAttributeName:NSColor.redColor()]
let styleBLUE = [NSForegroundColorAttributeName:NSColor.blueColor()]
let styleBOLD12 = [NSFontAttributeName:NSFont.boldSystemFontOfSize(12)]
let styleNORM12 = [NSFontAttributeName:NSFont.systemFontOfSize(12)]

/**
	@brief This class represents a running process and corresponds to one row in the NSTableView.

	I made it a class rather than a struct because two of the properties are Futures (check
	Future.swift for the implementation). Copying a struct while a Future is still unresolved
	will either make the copy never resolve, or will hurt my head if both resolve. :-)

	Rather than make a separate .swift file for this class, I found it easier to include it here.
 */

/*	Global functions for comparing ProcessInfos; must define < and ==
	Here we use the bundleName in Finder order, convenient for sorting.
 */
func < (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {	// required by Comparable
	return lhs.bundleName.localizedStandardCompare(rhs.bundleName) == NSComparisonResult.OrderedAscending
}

func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {	// required by Equatable and Comparable
	return lhs.bundleName.localizedStandardCompare(rhs.bundleName) == NSComparisonResult.OrderedSame
}

class ProcessInfo: DebugPrintable, Comparable {
	
///	This computed property is for debugging (DebugPrintable protocol)
	var debugDescription: String {
		return "“\(bundleName)”"
	}

///	This read-only property contains the localized bundle name (without extension).
	let bundleName: String

///	This is the backing property for the (computed) icon property. Internal use only!
	let _icon: Future<NSImage>

/**
	This is a computed property (so it must be var). It will get the future
	value from the _icon Future, meaning it will block while the icon
	is obtained.
 */
	var icon: NSImage {
		return _icon.value
	}

///	This is the backing property for the (computed) text property. Internal use only!
	let _text: Future<NSAttributedString>
	
/**
	This is a computed property (so it must be var). It will get the future
	value from the _text Future, meaning it will block while the text
	is obtained.
 */
	var text: NSAttributedString {
		return _text.value
	}
	
/**	This single & only initializer does all the heavy lifting.
	It uses Futures to get the bundle icon and to setup the displayed text, as it will
	contain the certificate summaries from the summaries.
 */
	init(_ theapp: NSRunningApplication) {

//	Precalculate some values we'll need later on
		let name = theapp.localizedName
		let url = theapp.bundleURL
		let fpath = url.path.stringByDeletingLastPathComponent
		let arch = theapp.executableArchitecture

		bundleName = name

//	The icon will probably be read from disk, so making this a Future is a good thing.
		_icon = Future {
			var image: NSImage = theapp.icon
			image.size = NSMakeSize(64,64)		// hardcoded to match the table column size
			return image
		}

/*	The text is built up in sections and, if a signature is present, this will get the sandboxed
	attribute and the signing certificates from the signature and append the summaries.
	Reading signatures from disk means a Future is useful, here, too.
 */
		_text = Future {

//	Start off with the localized bundle name in bold
			var result = NSMutableAttributedString(string: name, attributes: styleBOLD12)
			
//	Add the architecture as a bonus value
			switch arch {
			case NSBundleExecutableArchitectureI386:
				result += " (32-bit)"
			case NSBundleExecutableArchitectureX86_64:
				result += " (64-bit)"
			default:
				break
			}
			
//	Add the containing folder path — path components should be localized, perhaps?
			result += (" in “\(fpath)”\n...", styleNORM12)
			
//	GetCodeSignatureForURL() may return nil, an empty dictionary, or a dictionary with parts missing.
			if let signature = GetCodeSignatureForURL(url) {
				
//	The entitlements dictionary may also be missing.
				if let entitlements = signature["entitlements-dict"] as? NSDictionary {
					if let sandbox = entitlements["com.apple.security.app-sandbox"] as? NSNumber {
						
//	Even if the sandbox entitlement is present it may be 0
						if  sandbox.intValue != 0 {
							result += ("sandboxed, ", styleBLUE)	// blue text to stand out
						}
					}
				}
				
//	The certificates array may be empty or missing entirely.
				result += "signed "
				var signed = false;

//	Unfortunately, autoclosure of the right-hand side of && and || means you cannot do things like
//	if let a = b && a.f() { … }. Hence the Bool flag.
				if let certificates = signature["certificates"] as? NSArray {
					if certificates.count > 0 {
						signed = true
						
//	Some map & reduce calls to use 'functional programming' - note this creates an intermediate
//	summaries array. There usually are 3 certificates, so this isn't too onerous.
						let summaries = (certificates as Array).map {
							(cert) -> String in
							if let summary = GetCertSummary(cert) {
								return summary
							}
							return "<?>"	// GetCertSummary() returned nil
						}
						
//	Concatenating with commas is easy now
						result += "by "+summaries.reduce("") {
							return $0.isEmpty ? $1 : $0+", "+$1
						}
					}
				}
				
				if (!signed) {	// signed but no certificates
					result += "without certificates"
				}
			} else {	// code signature missing
				result += ("unsigned", styleRED)	// red text to stand out
			}
			return result
		}
	}
}

/**
	This class is the Application delegate and also drives the table view. It's easier to
	make a single class for such a simple case.
 */
class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {

/*	This Array contains the currently showing list of processes.
	
	I start out with an empty array because AppDelegate.numberOfRowsInTableView()
	is generally called several times before the array is filled.
 */
	var processes: [ProcessInfo] = []

//	These are normal outlets for UI elements.
	@IBOutlet var theWindow: NSWindow
	@IBOutlet var theTable: NSTableView


///	This NSTableViewDataSource method returns the number of processes: one per row.
	func numberOfRowsInTableView(tableView: NSTableView!) -> Int {
		return processes.count
	}

///	This NSTableViewDelegate method gets a NSTableCellView from the xib and
///	populates it with the process's icon or text.
	func tableView(tableView: NSTableView!, viewForTableColumn tableColumn: NSTableColumn!, row: Int) -> NSView! {
		let identifier = tableColumn.identifier
		let info = processes[row]

//	Note that in the xib "1" and "2" are identifiers for both NSTableColumns and NSTableCellViews.
		let view = tableView.makeViewWithIdentifier(identifier, owner: self) as NSTableCellView
		switch tableColumn.identifier! {
		case "1":
			view.imageView.image = info.icon	// blocks until the icon is ready
		case "2":
			view.textField.attributedStringValue = info.text	// blocks until the text is ready
		default:
			break
		}
		return view
	}

///	This NSTableViewDelegate method just prevents any row from being selected.
	func tableView(tableView: NSTableView!, shouldSelectRow row: Int) -> Bool {
		return false
	}

/**
	This action method is called when the refresh button is pressed, but also
	once when the app starts up.
	The argument is an optional because on startup it gets called with nil; since
	I don't use sender for anything, it could be tested to do extra stuff on startup.
 */
@IBAction func refreshButton(sender: AnyObject?) {

//	I get the list of running applications - note that this doesn't include processes running
//	outside user space.
		let apps = NSWorkspace.sharedWorkspace().runningApplications

//	I transform the process list into a sorted array of ProcessInfos. Note that I was able
//	to use the shorthand sort() call here since ProcessInfo conforms to Comparable.
		processes = apps.map {
			(app) -> ProcessInfo in
			return ProcessInfo(app as NSRunningApplication)
		}
		sort(&processes)	// new syntax in Xcode 6b3: sort parameter is inout, no value returned

//	All is ready now to reload the table. I could call reloadData directly here but
//	the UI would be slightly less responsive, and I wanted to test my PerformOnMain function.
		PerformOnMain {
			self.theTable.reloadData()
		}
	}

//	This NSApplicationDelegate method is called as soon as the app's icon begins
//	bouncing in the Dock.
	func applicationWillFinishLaunching(aNotification: NSNotification?) {

/*	I use the new transparent title bar option in 10.10
	(there seems to be no IB flag for it yet). The window's "visible at launch"
	option must be turned off for this to work.
 */
		theWindow.titlebarAppearsTransparent = true
		theWindow.styleMask |= NSFullSizeContentViewWindowMask
		theWindow.makeKeyAndOrderFront(self)

/*	I simulate a click on the refresh button, to set the table up for the
	first time - the Futures will make the protracted parts run in parallel
	while the app starts up.
 */
		refreshButton(nil)
	}

/**	This NSApplicationDelegate method is called when all is ready and the app's icon
	stops bouncing in the Dock.
 */
	func applicationDidFinishLaunching(aNotification: NSNotification?) {
//	Yep, it does nothing. Early on I had some debugging code in here.
	}

///	This NSApplicationDelegate method quits the app when the window is closed.
	func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication!)->Bool {
		return true
	}

}

