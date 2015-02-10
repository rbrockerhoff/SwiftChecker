//
//  main.swift
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 5/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

import Cocoa

//	This TimeStamp is used in AppDelegate to log startup and quit times.
let startup = TimeStamp()
PrintLN("Started at \(startup)")

NSApplicationMain(Process.argc, Process.unsafeArgv)

