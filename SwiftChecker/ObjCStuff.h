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

// These contains ObjC functions I did not manage to port (yet) to Swift. See the .m file for details.

/*!
	Accepts a generic object (actually a SecCertificateRef cast to id) representing a certificate.
	Returns an autoreleased NSString with the certificate summary, or nil.
	See the documentation for SecCertificateCopySubjectSummary() for details.
 */
//NSString* GetCertSummary(id cert);

