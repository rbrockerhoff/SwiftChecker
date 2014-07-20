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
	
/*	This Array contains the currently showing list of processes.
	
	I start out with an empty array because AppDelegate.numberOfRowsInTableView()
	is generally called several times before the array is filled.
 */
	var processes: [ ProcessInfo ] = [ ]
	
	///	This is a dictionary of the currently running processes, indexed by processIdentifier (pid)
	var procdict: [ pid_t : ProcessInfo ] = [ : ]
	
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
		
		//	Need the change kind as a number
		switch change[NSKeyValueChangeKindKey!] as NSNumber {
			
		//	...to match with raw values from the NSKeyValueChange enum. Least stressful way to do this?
		case NSKeyValueChange.Insertion.toRaw():
			
			//	Get the inserted apps (usually only one, but you never know
			if let apps = change[NSKeyValueChangeNewKey!] as? NSArray {
				//	Add the apps into the process dictionary
				_merge(apps)
			}
			
		case NSKeyValueChange.Removal.toRaw():
			
			//	Get the removed apps (usually only one, but you never know
			if let apps = change[NSKeyValueChangeOldKey!] as? NSArray {
				//	Remove the apps from the process dictionary
				_merge(apps)
			}
			
		default:
			return	// nothing to refresh; should never happen
		}
		
		//	Finally, refresh the table.
		_refresh()
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
		
		//	Build the process dictionary from the list of running applications	
		_merge(workspace.runningApplications)
		
		//	Finally, refresh the table.
		_refresh()
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
	}
	
//	--------------------------------------------------------------------------------
//	private functions

///	This function is called to refresh the table.
	func _refresh() {
		var time = TimeStamp("Table refresh")
		
		/*	Get the array of processes from the process dictionary, which at this point must be set up.
			Notice that procdict.values actually returns a lazily evaluated MapCollectionView, so we
			can sort it immediately.
		*/
		processes = sorted(procdict.values)
		
		/*	All is ready now to reload the table. That is better done on the main thread and
			this function may be called before the run loop is started, so I call PerformOnMain()
			which is the new way of doing performSelectorOnMainThread:
		*/
		PerformOnMain {
			self.theTable.reloadData()
		}
		
		PrintLN(time.freeze())
	}
	
	/**
		This function merges an array of NSRunningApplication into the procdict
		Dictionary, inserting or removing as necessary. It uses one of the Dictionary
		extensions for that.
	*/
	func _merge (apps: NSArray) {
		if let apps = apps as? Array<NSRunningApplication> {
			procdict.merge(apps) {
				(app) in
				let pid = app.processIdentifier
				if pid == -1 {
					return nil	//	ignore apps without a pid
				}
				let remove = app.terminated
				let msg = remove ? "Removed " : "Inserted "
				PrintLN(msg + app.localizedName)
				return (pid, remove ? nil : ProcessInfo(app))
			}
		}
	}
	
}	// end of AppDelegate

///	global variable used as unique context for KVO
var KVOContext: Int = 0

//	--------------------------------------------------------------------------------
/*	Extensions to Dictionary. SwiftChecker uses only one of those, but they
	may be useful elsewhere.

	The idea is to modify the Dictionary, either from an input array of (key,value) tuples,
	or from an input array of any type which is then processed by a generator function/closure
	to produce the tuples.

	In the latter case, the generator function can return nil to filter out that item
	from the input array, return a (key,value) tuple to insert or change an item, or
	a (key,nil) tuple to remove an item. See ProcessInfo._merge() above for an example.

	Both types of funcs are duplicated to accept either an Array or a Sequence, which should
	cover most common cases - basically, you should be able to pass in anything that
	can also appear in a for…in statement. (Haven't tested for Ranges and Slices, though.)
*/

extension Dictionary {
	
//	Allow merging an array of (key,value) tuples to a Dictionary.
	mutating func merge (array: Array<Element>) {
		for (key: KeyType, value: ValueType) in array {
			self[key] = value
		}
	}
	
//	Allow merging a sequence of (key,value) tuples to a Dictionary.
	mutating func merge <S: Sequence where S.GeneratorType.Element == Element> (seq: S) {
		var gen = seq.generate()
		while let (key: KeyType, value: ValueType) = gen.next() {
			self[key] = value
		}
	}
	
//	Allow merging an array of values to a Dictionary, by specifying a generator function.
	mutating func merge <T> (array: Array<T>, filter: (T) -> (KeyType, ValueType?)?) {
		for t in array {
			if let (key: KeyType, value: ValueType?) = filter(t) {
				self[key] = value ? value! : nil
			}
		}
	}
	
//	Allow merging a sequence of values to a Dictionary by specifying a generator function.
	mutating func merge <T, S: Sequence where S.GeneratorType.Element == T> (seq: S, filter: (T) -> (KeyType, ValueType?)?) {
		var gen = seq.generate()
		while let t: T = gen.next() {
			if let (key: KeyType, value: ValueType?) = filter(t) {
				self[key] = value ? value! : nil
			}
		}
	}
	
}	// end of Dictionary extension

