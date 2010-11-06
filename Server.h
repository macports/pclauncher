//
//  Server.h
//  PCLauncher
//
//  Created by Ryan Schmidt on 2010-11-02.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Server : NSObject {
	NSString *serverIniFilename;
	NSString *internalName;
	NSString *displayName;
	NSString *statusUrl;
	NSString *createAccountUrl;
	NSString *status;
	id statusField;
	NSMutableData *statusData;
}

- (id)initWithIniFilename:(NSString *)file;
- (void)showStatusInField:(id)field;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)openCreateAccountUrl;
- (BOOL)isDefaultServer;

@property (readonly, assign) NSString *serverIniFilename;
@property (readonly, assign) NSString *internalName;
@property (readonly, assign) NSString *displayName;
@property (readonly, assign) NSString *createAccountUrl;

@end
