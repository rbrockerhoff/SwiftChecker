//
//  AppDelegate.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 5/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

import Cocoa
import Foundation

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

@assignment func += (inout left: NSMutableAttributedString, right: (str: String, att: NSDictionary!)) {
	left.appendAttributedString(NSAttributedString(string: right.str, attributes: right.att))
}

//	Some preset style attributes for that last function
let styleRED = [NSForegroundColorAttributeName:NSColor.redColor()]
let styleBLUE = [NSForegroundColorAttributeName:NSColor.blueColor()]
let styleBOLD12 = [NSFontAttributeName:NSFont.boldSystemFontOfSize(12)]
let styleNORM12 = [NSFontAttributeName:NSFont.systemFontOfSize(12)]


/*!
	This class represents a running process and corresponds to one row in the NSTableView.

	I made it a class rather than a struct because two of the properties are Futures (check
	Future.swift for the implementation). Copying a struct while a Future is still unresolved
	will either make the copy never resolve, or will hurt my head if both resolve. :-)

	Rather than make a separate .swift file for this class, I found it easier to include it here.
	Some code was copied back & forth from the AppDelegate class during debugging, and it's a
	very short class anyway...
 */
class ProcessInfo {

/*!
	This read-only property contains the bundle name (without extension).
 */
	let bundleName: NSString

//	This is the backing property for the (computed) icon property.
	let _icon: Future<NSImage>		// don't use from outside

/*!
	This is a computed property (so it must be var). It will get the future
	value from the _icon Future, meaning it will block while the icon
	is obtained.
 */
	var icon: NSImage {
		return _icon.value()
	}

//	This is the backing property for the (computed) text property.
	let _text: Future<NSAttributedString>		// don't use from outside
	
/*!
	This is a computed property (so it must be var). It will get the future
	value from the _text Future, meaning it will block while the text
	is obtained.
 */
	var text: NSAttributedString {
		return _text.value()
	}

/*	This single & only initializer does all the heavy lifting. The parameter must be a file URL
	for the bundle/executable. (I don't test for that, as the only source promises returning
	only file URLs.)
	It precalculates the process name from the URL as well as the containing folder path.
	It uses Futures to get the bundle icon and to setup the displayed text, as it will
	contain the certificate summaries from the summaries.
 */
	init(_ theurl: NSURL) {
		let path = theurl.path
		let name = path.lastPathComponent.stringByDeletingPathExtension
		let fpath = path.stringByDeletingLastPathComponent

		bundleName = name

//	The icon will probably be read from disk, so making this a Future is a good thing.
		_icon = Future {
			var image: NSImage! = NSWorkspace.sharedWorkspace().iconForFile(path)
			image.size = NSMakeSize(64,64)		// hardcoded to match the table column size
			return image
		}

/*	The text is set up in sections and, if a signature is present, this will get the sandboxed
	attribute and the signing certificates from the signature and append the summaries.
	Reading signatures from disk means a Future is indicated, here, too.
 */
		_text = Future {
			var txt = NSMutableAttributedString(string: name, attributes: styleBOLD12)
			txt += (" in “\(fpath)”\n...", styleNORM12)

//	GetCodeSignatureForURL() may return nil, an empty dictionary, or a dictionary with parts missing.
			var signed = false
			if let sign: NSDictionary! = GetCodeSignatureForURL(theurl) {
				var sandboxed = false

//	The entitlements dictionary may also be missing. Notice the intermediate casts to AnyObject?.
//	Without this the compiler balks - it's a workaround.
				if let entitlements: NSDictionary? = (sign["entitlements-dict"] as AnyObject?) as NSDictionary? {
					if let ents = entitlements {
						if let casas: NSNumber? = (ents["com.apple.security.app-sandbox"] as AnyObject?) as NSNumber? {
							if  casas!.intValue != 0 {
								sandboxed = true
								txt += ("sandboxed", styleBLUE)
							}
						}
					}
				}

//	The certificates array may be empty or missing entirely. Rare, but I've seen cases.
				if let certificates: NSArray? = (sign["certificates"] as AnyObject?) as NSArray? {
					if let certs = certificates {
						if sandboxed {
							txt += ", "
						}
						signed = true
						txt += "signed by "
						if certs.count > 0 {
							for index in 0..certs.count {
								if (index>0) {
									txt += ", "
								}

//	GetCertSummary() may conceivably return nil if the certificate is malformed, but I've
//	never seen a case, so I don't test for it.
								txt += GetCertSummary(certs[index])
							}
						} else {
							txt += "no certificates"
						}
					}
				}
			}
			if !signed {
				txt += ("unsigned", styleRED)
			}
			return txt
		}
	}
}

/*!
	This class is the Application delegate and also drives the table view. Easier to
	make a single class for such a simple case.
 */
class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {

//	These are normal outlets for UI elements.
	@IBOutlet var theWindow: NSWindow
	@IBOutlet var theTable: NSTableView

//	This array is a list of ProcessInfo objects, one for each process.
//	I start out with an empty array because numberOfRowsInTableView()
//	is called several times before the array is filled.
	var processes: Array<ProcessInfo> = []

//	This NSTableViewDataSource method returns the number of processes:
//	one per row.
	func numberOfRowsInTableView(tableView: NSTableView!) -> Int {
		return processes.count
	}

//	This NSTableViewDelegate method gets a NSTableCellView from the xib and
//	populates it with the process's icon or text.
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

//	This NSTableViewDelegate method just prevents any row from being selected.
	func tableView(tableView: NSTableView!, shouldSelectRow row: Int) -> Bool {
		return false
	}

/*!
	This action method is called when the refresh button is pressed, but also
	once when the app starts up.
	The argument is an optional because on startup it gets called with nil; since
	I don't use sender for anything, it could be tested to do extra stuff on startup.
 */
	@IBAction func refreshButton(sender: AnyObject?) {

//	We get the list of running applications - note that this doesn't include processes running
//	outside user space.
		let apps = NSWorkspace.sharedWorkspace().runningApplications

//	We transform the process list into an array of ProcessInfos
		let array = apps.map {
			(var app) -> ProcessInfo in
			return ProcessInfo(app.bundleURL)
		}

//	and sort it with the same comparation used by the Finder for filenames.
		array.sort {$0.bundleName.localizedStandardCompare($1.bundleName) == NSComparisonResult.OrderedAscending}
//	Weirdly enough, sorting the processes array has no effect - must be those weird array semantics,
//	so I sort this local array and then assign it.
		processes = array

//	All is ready now to reload the table. I could call reloadData directly here but
//	the UI would be slightly less responsive, and I wanted to test my PerformOnMain function.
		PerformOnMain {
			self.theTable.reloadData()
		}
	}

//	This NSApplicationDelegate method is called as soon as the app's icon begins
//	bouncing in the Dock.
	func applicationWillFinishLaunching(aNotification: NSNotification?) {

/*	First I simulate a click on the refresh button, to set the table up for the
	first time - the Futures will make the protracted parts run in parallel
	while the app starts up.
 */
		refreshButton(nil)

/*	I use the new transparent title bar option in 10.10
	(there seems to be no IB flag for it yet). The window's "visible at launch"
	option must be turned off for this to work.
 */
		theWindow.titlebarAppearsTransparent = true
		theWindow.styleMask |= NSFullSizeContentViewWindowMask
		theWindow.makeKeyAndOrderFront(self)
	}

/*	This NSApplicationDelegate method is called when all is ready and the app's icon
	stops bouncing in the Dock.
 */
	func applicationDidFinishLaunching(aNotification: NSNotification?) {
// right, it does nothing. Early on I had some debugging code in here.
	}

//	This NSApplicationDelegate method quits the app when the window is closed.
	func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication!)->Bool {
		return true
	}

}

