//
//  AppDelegate.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 5/6/14.
//  Copyright (c) 2014-2015 Rainer Brockerhoff. All rights reserved.
//

import Cocoa

//MARK: private class AppDelegate
//	================================================================================
/**
# AppDelegate
This class is the Application delegate and also drives the table view. It's easier to make a single class for
such a simple app.

Since Xcode 6.1 the application delegate class (and I suppose others loaded from .xibs) must be public.
*/
public class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
	
//	--------------------------------------------------------------------------------
//MARK: properties and outlets
	
/**
This is a dictionary of the currently running processes — the user-visible ones, that is.

The key is a NSRunningApplication and the value is a ProcessInfo, which is actually built from that key —
it contains data generated and cached for display.

I start out with an empty dict and update it dynamically inside _update().

In previous versions this was keyed by NSRunningApplication.processIdentifier (pid) but it
turns out that applications can be quit automatically (losing their pid) and then restart and be assigned
a new one, messing up the display.

Using NSRunningApplication as the dictionary key leverages the docs' recommendation:
"Do not rely on pid for comparing processes, instead compare NSRunningApplication instances using isEqual:".
*/
private var procdict: [ NSRunningApplication : ProcessInfo ] = [ : ]
	
/**
This Array contains cached data for the current list of processes in the GUI.
It is rebuilt from the procdict Dictionary inside _update().

I start out with an empty array because AppDelegate.numberOfRowsInTableView() is generally
called several times before the array is filled.
*/
	private var processes: [ ProcessInfo ] = [ ]
	
	//	These are normal outlets for UI elements.
	@IBOutlet var theWindow: NSWindow!
	@IBOutlet var theTable: NSTableView!
	
//	--------------------------------------------------------------------------------
//MARK: NSTableViewDataSource and NSTableViewDelegate methods

	///	This NSTableViewDataSource method returns the number of processes: one per row.
	public func numberOfRowsInTableView(tableView: NSTableView) -> Int {
		return processes.count
	}
	
	///	This NSTableViewDelegate method gets a NSTableCellView from the xib and
	///	populates it with the process's icon or text.
	public func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard row < processes.count else {	// new guard syntax prevents a rare crash when the last app in the table quits
			return nil
		}
		let info = processes[row]
		if let identifier = tableColumn?.identifier,
			view = tableView.makeViewWithIdentifier(identifier, owner: self) as? NSTableCellView {
			//	Note that in the xib "1" and "2" are identifiers for both NSTableColumns and NSTableCellViews.
			switch identifier {
			case "1":
				view.imageView!.image = info.icon	// blocks until the icon is ready
			case "2":
				view.textField!.attributedStringValue = info.text	// blocks until the text is ready
			default:
				break
			}
			return view
		}
		return nil
	}
	
	///	This NSTableViewDelegate method just prevents any row from being selected.
	public func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		return false
	}
	
//	--------------------------------------------------------------------------------
//MARK: observers

///	This KVO observer is called whenever the list of running applications changes.
	public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		var apps: NSArray? = nil
		
		//	This uses the new guard statement to return early if there's no change dictionary.
		guard let change = change else {
			return
		}

		if let rv = change[NSKeyValueChangeKindKey] as? UInt,
			kind = NSKeyValueChange(rawValue: rv) {
			switch kind {
			case .Insertion:
				//	Get the inserted apps (usually only one, but you never know)
				apps = change[NSKeyValueChangeNewKey] as? NSArray
			case .Removal:
				//	Get the removed apps (usually only one, but you never know)
				apps = change[NSKeyValueChangeOldKey] as? NSArray
			default:
				return	// nothing to refresh; should never happen, but...
			}
		}
	
		// update the table with the changes (if any)
		_update(apps)
	}
	
//	--------------------------------------------------------------------------------
//MARK: NSApplicationDelegate methods

	///	This NSApplicationDelegate method is called as soon as the app's icon begins
	///	bouncing in the Dock.
	public func applicationWillFinishLaunching(aNotification: NSNotification) {
		
		//	This is one of several prints of timing information that works only on Debug builds.
		//	Note that startup is defined/initialized inside main.swift!
		Print("willFinish; \(startup.age) after startup")

		let workspace = NSWorkspace.sharedWorkspace()

		//	This adds the app delegate as observer of NSWorkspace's list of running applications.
		//	(note that this list only includes processes running inside user space)
		workspace.addObserver(self, forKeyPath: "runningApplications", options: [.Old, .New], context: &KVOContext)
		
		//	Update the table with the list of running applications
		_update(workspace.runningApplications)
	}
	
	/**	This NSApplicationDelegate method is called when all is ready and the app's icon
		stops bouncing in the Dock.
	 */
	public func applicationDidFinishLaunching(Notification: NSNotification) {
		Print("didFinish; \(startup.age) after startup")
		//	Yep, it does nothing else. Early on I had some debugging code in here.
	}
	
	///	This NSApplicationDelegate method quits the app when the window is closed.
	public func applicationShouldTerminateAfterLastWindowClosed(theApplication: NSApplication) -> Bool {
		return true
	}
	
	///	This NSApplicationDelegate method is called just before termination.
	public func applicationWillTerminate(aNotification: NSNotification) {
		Print("willTerminate; \(startup.age) after startup")
		
		// remove the observer we added in applicationWillFinishLaunching
		NSWorkspace.sharedWorkspace().removeObserver(self, forKeyPath: "runningApplications")
	}

//	--------------------------------------------------------------------------------
//MARK: private functions

/**
This function updates the GUI based on an Array of changed NSRunningApplications.
*/
	private func _update(apps: NSArray?) {
		
		///	Proceed if we really have an Array of applications - may be nil.
		if let apps =  apps as? Array<NSRunningApplication>  {
			var time = TimeStamp("Table refresh")
			
			/// Use one of the Dictionary extensions to merge the changes into procdict.
			procdict.merge(apps) { (app) in
				let remove = app.terminated		// insert or remove?
				let msg = remove ? "Removed " : "Inserted "
				Print(msg + app.localizedName!)
				return (app, remove ? nil : ProcessInfo(app))
			}
			
			///	Produce a sorted Array of ProcessInfo as input for the NSTableView.
			///	ProcessInfo conforms to Equatable and Comparable, so no predicate is needed.
			processes = procdict.values.sort()

			/*	All is ready now to reload the table. That is better done on the main thread and
				this function will be called before the run loop is started, so I call PerformOnMain()
				which is my new way of doing performSelectorOnMainThread:
			*/
			PerformOnMain {
				self.theTable.reloadData()
			}
			
			Print(time.freeze())
		}
	}
	
}	// end of AppDelegate

//MARK: globals
///	global variable used as unique context for KVO
private var KVOContext: Int = 0

//MARK:	extensions
//	--------------------------------------------------------------------------------
/**
	Extensions to Dictionary. SwiftChecker uses only one of those, but they
	may be useful elsewhere.

	The idea is to modify the Dictionary, either from an input Sequence of (key,value) tuples,
	or from an input Sequence of any type which is then processed by a filter function/closure
	to produce the tuples.

	In the latter case, the filter function can return nil to filter out that item
	from the input Sequence, return a (key,value) tuple to insert or change an item, or
	a (key,nil) tuple to remove an item. See AppDelegate._update() above for an example.
*/

extension Dictionary {
	
/**
Merges a sequence of (key,value) tuples into a Dictionary.
*/
	mutating func merge <S: SequenceType where S.Generator.Element == Element> (seq: S) {
		var gen = seq.generate()
		while let (key, value): (Key, Value) = gen.next() {
			self[key] = value
		}
	}
	
/**
Merges a sequence of values into a Dictionary by specifying a filter function.

The filter function can return nil to filter out that item from the input Sequence, or return a (key,value)
tuple to insert or change an item. In that case, value can be nil to remove the item for that key.
*/
	mutating func merge <T, S: SequenceType where S.Generator.Element == T> (seq: S, filter: (T) -> (Key, Value?)?) {
		var gen = seq.generate()
		while let t: T = gen.next() {
			if let (key, value): (Key, Value?) = filter(t) {
				self[key] = value
			}
		}
	}
	
}	// end of Dictionary extension

