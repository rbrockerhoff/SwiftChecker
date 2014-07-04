SwiftChecker
============

This is a simple real-world OS X application I wrote for getting up to speed in Swift; I hope it's useful. My main intentions were to learn something about having parts in Swift and parts in ObjC; also to translate some of my experience with asynchronous execution to Swift. Since GCD and blocks/closures are already a part of system services and the C language (contrary to some people who claim they're ObjC/Cocoa APIs), I found that it's easy to call them from Swift either directly or with some small convenience wrappers.

The application displays a single window containing a table of running applications/processes (user space only).

For each process, it displays the icon, name and containing folder, as well as sandbox status (if present) and summaries for signing certificates (if present).

The table is not updated automatically, but there's a refresh button to update it. A suggested exercise would be to listen to notifications for application start/stop and update the list dynamically.

Updating the table might potentially take some time if the system is very busy, since code signatures and icons will probably have to be loaded from disk. To speed this up, a simple "Future" class is implemented and used to perform these accesses asynchronously. In my timing tests, this accelerates table refresh by just under 4x — quite fair on a 4-core machine.

The project should build and run with no errors, warnings or crashes on OS X 10.10b2 and Xcode 6b2.

There are copious comments that, hopefully, explain some of the design decisions and workarounds where necessary.

The Xcode project itself is largely unchanged from the default setup and options. Exceptions:
- The test target and source file are there, but I didn't do anything with them.
- There is ObjC code in the ObjCStuff.m and .h files, both to learn about bridging the two languages, and because calling some C functions from Swift is still seriously tricky, and the documentation is lacking.
- Specifically, ARC is disabled on the ObjC files for the same reason.
- Some build options have been set, most importantly "treat warnings as errors".

---
Check out more Swift stuff [on my blog](http://brockerhoff.net/blog/tag/swift).
Please email comments to <rainer@brockerhoff.net>. This is intended as sample code, not as a collaborative open source project. Read the license for details.