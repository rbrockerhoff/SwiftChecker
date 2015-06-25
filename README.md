SwiftChecker
============

This is a simple real-world OS X application I wrote for getting up to speed in Swift; I hope it's useful. My main intentions were to learn something about having parts in Swift and parts in ObjC; also to translate some of my experience with asynchronous execution to Swift. Since GCD and blocks/closures are already a part of system services and the C language (contrary to some people who claim they're ObjC/Cocoa APIs), I found that it's easy to call them from Swift either directly or with some small convenience wrappers. After some learning, I was able to delete the ObjC parts in this latest version.

The application displays a single window containing a table of running applications/processes (user space only).

For each process, it displays the icon, name and containing folder, as well as sandbox status (if present) and summaries for signing certificates (if present).

Updating the table might potentially take some time if the system is very busy, since code signatures and icons will probably have to be loaded from disk. To speed this up, a simple "Future" class is implemented and used to perform these accesses asynchronously. In my initial timing tests, this accelerated table refresh by just under 4x — quite fair on a 4-core machine. In subsequent versions, the various filter/map/sort operations are evaluated lazily, and only the changes are processed; so the impact on table refresh is almost imperceptible. Still, I left the Futures in for evaluation.

The Timing.swift file contains timing and benchmarking utilities which might come handy in other projects. The classes and functions in Future.swift can also be used elsewhere.

The project should build and run with no errors, warnings or crashes on the latest versions of OS X 10.10 and Xcode 7 beta 2. In theory if you set the target version to 10.9 it should work there (but I haven't tried). The target SDK must now be 10.10 for Swift apps. Not tested (as yet) on 10.11.

There are copious comments that, hopefully, explain some of the design decisions and workarounds where necessary. I'm trying out various comment styles and placements; along with the new whitespace conventions, this will hopefully converge to a new and consistent coding style for my Swift source code.

The Xcode project itself is largely unchanged from the default setup and options. Exceptions:
- The test target and source file are there, but I didn't do anything with them.
- Some build options have been set, most importantly "treat warnings as errors", and "-D DEBUG" in "Other Swift Flags".

Known issues:
- The BenchmarkParallel() functions take way too long; I'm still testing the benchmarks.
- The Future and FutureThrows classes should have similar APIs.

Recent changes:
- Fixes for Xcode 7 beta 2 - autoconverted to Swift 2, throwing futures, guards, new syntax elsewhere, QuickHelp comments
- Fixes for Xcode 6.3 beta 3 - UInt is gone almost everywhere
- Fixes for Xcode 6.3 beta 2 - more restricted @autoclosure, Future(expression) deleted, more optionals changed
- Fixes for Xcode 6.1GM - less casts needed, app delegate must be public, changes to optionals
- Fixed a rare crash when the last app in the table quit.
- Futures now use a custom queue to avoid the 64-thread limit on the main queues.
- Still messing around with the benchmarking functions.
- Fixed a bug when applications were automatically quit.
- Small cosmetic fixes.
- __conversion() taken out.
- Some more refactoring for less code.
- For Debug builds various timing information is printed to the console.
- General source and comments reorganization, hopefully for better readability.
- The ProcessInfo class has been split off into its own source file.
- A new FutureDebug class is available.
- A new Timing.swift file contains various timing and benchmarking utilities.
- The table is now updated automatically and the refresh button has been removed.
- The ObjCStuff.m and .h files have been removed since I solved the porting problems.

---
Check out more Swift stuff [on my blog](http://brockerhoff.net/blog/tag/swift).
Please email comments to <rainer@brockerhoff.net>. This is intended as sample code, not as a collaborative open source project. Read the license for details.
