//
//  ObjCStuff.m
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 26/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

#import "ObjCStuff.h"

/*
	This code is from pre-ARC days and abuses toll-free bridging (regarding retain/release
	and autorelease). After a couple of days of crashing the compiler while trying to call
	these APIs directly from Swift, I gave up for now.
 */

NSDictionary* GetCodeSignatureForURL(CFURLRef url) {
	NSMutableDictionary* dict = nil;
	SecStaticCodeRef code = NULL;
	if (url) {
		OSStatus err = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &code);
		if (err==noErr) {
			err = SecCodeCopySigningInformation(code, kSecCSSigningInformation, (CFDictionaryRef*)&dict);
			CFRelease(code);
		}
	}
	return [dict autorelease];
}

NSString* GetCertSummary(id cert) {
	NSString* summary = (NSString*)SecCertificateCopySubjectSummary((SecCertificateRef)cert);
	return summary ? [summary autorelease] : @"";
}


