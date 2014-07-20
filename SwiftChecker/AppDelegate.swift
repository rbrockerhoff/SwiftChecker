//
//  AppDelegate.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 5/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

import Cocoa

//	================================================================================
/**
	This class is the Application delegate and also drives the table view. It's easier to
	make a single class for such a simple app.
*/
class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
	
/**
	This is a dictionary of the currently running processes. The key is a NSRunningApplication
	and the value is a ProcessInfo, which is actually built from that key — it contains data
	generated and cached for display.

	I start out with an empty dict and update it dynamically inside _update().
	
	In previous versions this was keyed by NSRunningApplication.processIdentifier (pid) but it turns
	out that applications can be quit automatically (losing their pid) and then restart and be assigned
	a new one, messing up the display.
 */
	var procdict: [ NSRunningApplication : ProcessInfo ] = [ : ]
	
/**
	This Array contains cached data for the current list of processes in the GUI.
	It is rebuilt from the procdict Dictionary inside _update().
	
	I start out with an empty array because AppDelegate.numberOfRowsInTableView()
	is generally called several times before the array is filled.
 */
	var processes: [ ProcessInfo ] = [ ]
	
	//	These are normal outlets for UI elements.
	@IBOutlet var theWindow: NSWindow
	@IBOutlet var theTable: NSTableView
	
//	--------------------------------------------------------------------------------
//	NSTableViewDataSource and NSTableViewDelegate methods

	///	This NSTableViewDataSource method returns the number of processes: one per row.
	func numberOfRowsInTableView(tableView: NSTableView!) -> Int {
		return processes.count
	}
	
	///	This NSTableViewDelegate method gets a NSTableCellView from the xib and
	///	populates it with the process's icon or text.
	func tableView(tableView: NSTableView!, viewForTableColumn tableColumn: NSTableColumn!, row: Int) -> NSView! {
		let identifier = tableColumn.identifier!
		let info = processes[row]
		
		//	Note that in the xib "1" and "2" are identifiers for both NSTableColumns and NSTableCellViews.
		let view = tableView.makeViewWithIdentifier(identifier, owner: self) as NSTableCellView
		switch identifier {
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
	
//	--------------------------------------------------------------------------------
//	Observers

///	This KVO observer is called whenever the list of running applications changes.
	override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [ NSObject : AnyObject]!, context: UnsafePointer<()>) {
		
		var apps: NSArray? = nil

		//	Need the change kind as a number
		switch change[NSKeyValueChangeKindKey!] as NSNumber {
			
		//	...to match with raw values from the NSKeyValueChange enum. Least stressful way to do this?
		case NSKeyValueChange.Insertion.toRaw():
			
			//	Get the inserted apps (usually only one, but you never know
			apps = change[NSKeyValueChangeNewKey!] as? NSArray

		case NSKeyValueChange.Removal.toRaw():
			
			//	Get the removed apps (usually only one, but you never know
			apps = change[NSKeyValueChangeOldKey!] as? NSArray

		default:
			return	// nothing to refresh; should never happen, but...
		}
	
		// update the table with the changes (if any)
		_update(apps)
	}
	
//	--------------------------------------------------------------------------------
//	NSApplicationDelegate methods

	///	This NSApplicationDelegate method is called as soon as the app's icon begins
	///	bouncing in the Dock.
	func applicationWillFinishLaunching(aNotification: NSNotification?) {
		
		//	This is one of several prints of timing information that works only on Debug builds.
		//	Note that startup is defined/initialized inside main.swift!
		PrintLN("willFinish; \(startup.age) after startup")
		
		let workspace = NSWorkspace.sharedWorkspace()

		//	This adds the app delegate as observer of NSWorkspace's list of running applications.
		//	(note that this list only includes processes running inside user space)
		workspace.addObserver(self, forKeyPath: "runningApplications", options: .Old | .New, context: &KVOContext)
		
		//	Update the table with the list of running applications
		_update(workspace.runningApplications)
	}
	
	/**	This NSApplicationDelegate method is called when all is ready and the app's icon
		stops bouncing in the Dock.
	 */
	func applicationDidFinishLaunching(aNotification: NSNotification?) {
		PrintLN("didFinish; \(startup.age) after startup")
		//	Yep, it does nothing else. Early on I had some debugging code in here.
	}
	
	///	This NSApplicationDelegate method quits the app when the window is closed.
	func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication!)->Bool {
		return true
	}
	
	///	This NSApplicationDelegate method is called just before termination.
	func applicationWillTerminate(aNotification: NSNotification!) {
		PrintLN("willTerminate; \(startup.age) after startup")
		NSWorkspace.sharedWorkspace().removeObserver(self, forKeyPath: "runningApplications")
	}
	
//	--------------------------------------------------------------------------------
//	private functions

	///	This function updates the GUI based on an Array of changed NSRunningApplications.
	func _update (apps: NSArray?) {
		
		///	Proceed if we really have an Array of applications - may be nil.
		if let apps = apps as? Array<NSRunningApplication> {
			var time = TimeStamp("Table refresh")
			
			/// Use one of the Dictionary extensions to merge the changes into procdict.
			procdict.merge(apps) { (app) in
				let remove = app.terminated		// insert or remove?
				let msg = remove ? "Removed " : "Inserted "
				PrintLN(msg + app.localizedName)
				return (app, remove ? nil : ProcessInfo(app))
			}
			
			///	Produce a sorted Array of ProcessInfo as input for the NSTableView.
			///	ProcessInfo conforms to Equatable and Comparable, so no predicate is needed.
			processes = sorted(procdict.values)

			/*	All is ready now to reload the table. That is better done on the main thread and
				this function will be called before the run loop is started, so I call PerformOnMain()
				which is my new way of doing performSelectorOnMainThread:
			*/
			PerformOnMain {
				self.theTable.reloadData()
			}
			
			PrintLN(time.freeze())
		}
	}
	
}	// end of AppDelegate

///	global variable used as unique context for KVO
var KVOContext: Int = 0

//	--------------------------------------------------------------------------------
/*	Extensions to Dictionary. SwiftChecker uses only one of those, but they
	may be useful elsewhere.

	The idea is to modify the Dictionary, either from an input Sequence of (key,value) tuples,
	or from an input Sequence of any type which is then processed by a generator function/closure
	to produce the tuples.

	In the latter case, the generator function can return nil to filter out that item
	from the input Sequence, return a (key,value) tuple to insert or change an item, or
	a (key,nil) tuple to remove an item. See AppDelegate._update() above for an example.
*/

extension Dictionary {
	
//	Allow merging a sequence of (key,value) tuples to a Dictionary.
	mutating func merge <S: Sequence where S.GeneratorType.Element == Element> (seq: S) {
		var gen = seq.generate()
		while let (key: KeyType, value: ValueType) = gen.next() {
			self[key] = value
		}
	}
	
//	Allow merging a sequence of values to a Dictionary by specifying a generator function.
	mutating func merge <T, S: Sequence where S.GeneratorType.Element == T> (seq: S, filter: (T) -> (KeyType, ValueType?)?) {
		var gen = seq.generate()
		while let t: T = gen.next() {
			if let (key: KeyType, value: ValueType?) = filter(t) {
				self[key] = value
			}
		}
	}
	
}	// end of Dictionary extension

