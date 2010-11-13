//
//  Server.mm
//  PCLauncher
//
//  Created by Ryan Schmidt on 2010-11-02.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Stream/plEncryptedStream.h>
#import <Util/plString.h>

#import "Server.h"

@implementation Server

- (id)initWithIniFilename:(NSString *)filename {
	self = [super init];
	if (self) {
		serverIniFilename = [filename retain];
		internalName = [[[serverIniFilename lastPathComponent] stringByDeletingPathExtension] retain];
		displayName = [[NSString alloc] initWithString:internalName];
		statusUrl = nil;
		createAccountUrl = nil;
		status = nil;
		statusField = nil;

		if ([[NSFileManager defaultManager] fileExistsAtPath:serverIniFilename]) {
			plEncryptedStream stream(PlasmaVer::pvMoul);
			if (stream.open([serverIniFilename fileSystemRepresentation], fmRead, plEncryptedStream::kEncXtea)) {
				NSString *line;
				NSRange separator;
				while (!stream.eof()) {
					line = [NSString stringWithUTF8String:stream.readLine().cstr()];
					separator = [line rangeOfString:@" "];
					NSString *key = [line substringToIndex:separator.location];
					NSString *value = [line substringFromIndex:(separator.location + 1)];
					if ([key isEqualToString:@"Server.DispName"]) {
						[displayName release];
						displayName = [[NSString alloc] initWithString:value];
					} else if ([key isEqualToString:@"Server.Url"]) {
						[statusUrl release];
						statusUrl = [[NSString alloc] initWithFormat:@"http://%@/serverstatus/moullive.php", value];
					} else if ([key isEqualToString:@"Server.Status"]) {
						[statusUrl release];
						statusUrl = [[NSString alloc] initWithString:value];
					} else if ([key isEqualToString:@"Server.Signup"]) {
						[createAccountUrl release];
						createAccountUrl = [[NSString alloc] initWithString:value];
					}
				}
				stream.close();
			}
		}
	}
	return self;
}

- (void)showStatusInField:(id)field {
	[statusField release];
	statusField = [field retain];
	if (status != nil) {
		[statusField setStringValue:status];
	} else {
		[statusField setStringValue:@""];
		if (statusUrl == nil) return;
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:statusUrl]
												 cachePolicy:NSURLRequestUseProtocolCachePolicy
											 timeoutInterval:60.0];
		NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
		if (connection) {
			statusData = [[NSMutableData alloc] init];
		} else {
			[statusField setStringValue:[NSString stringWithFormat:@"Could not get server status: %@", @"Could not open a connection."]];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [statusData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [statusData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [statusField setStringValue:[NSString stringWithFormat:@"Could not get server status: %@", [error localizedDescription]]];
    [connection release];
    [statusData release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[status release];
	status = [[NSString alloc] initWithBytes:[statusData bytes]
									  length:[statusData length]
									encoding:NSUTF8StringEncoding];
    [statusField setStringValue:status];
    [connection release];
    [statusData release];
}

- (void)openCreateAccountUrl {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:createAccountUrl]];
}

- (BOOL)isDefaultServer {
	return [internalName isEqualToString:@"default"];
}

- (NSString *)internalName {
	return internalName;
}

- (NSString *)displayName {
	return displayName;
}

- (NSString *)createAccountUrl {
	return createAccountUrl;
}

- (void)dealloc {
	[serverIniFilename release];
	[internalName release];
	[displayName release];
	[statusUrl release];
	[createAccountUrl release];
	[status release];
	[statusField release];
	[super dealloc];
}

@end
