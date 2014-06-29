//
//  ObjCStuff.h
//  SwiftChecker
//
//  Created by Rainer Brockerhoff on 26/6/14.
//  Copyright (c) 2014 Rainer Brockerhoff. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <Security/Security.h>
#include <Security/CodeSigning.h>

// These are functions I felt more comfortable writing in ObjC. See the .m file for details.

/*!
	Accepts a CFURLRef to a (hopefully codesigned) bundle or executable.
	Returns an autoreleased NSDictionary with basic codesigning data, or nil.
	See the documentation for SecCodeCopySigningInformation() for details.
 */
NSDictionary* GetCodeSignatureForURL(CFURLRef);

/*!
	Accepts a generic object (actually a SecCertificateRef cast to id) representing a certificate.
	Returns an autoreleased NSString with the certificate summary, or nil.
	See the documentation for SecCertificateCopySubjectSummary() for details.
 */
NSString* GetCertSummary(id cert);

