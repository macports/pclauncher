//
//  LoginWindowController.m
//
//  Created by Ryan Schmidt on 2010-10-26.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "LoginWindowController.h"

@implementation LoginWindowController

@synthesize preferencesWindowController;

enum {
	kStepIdle,
	kStepAuthenticating,
	kStepDownloadingSecureFiles,
	kStepExtractingSecureFiles,
	kStepLaunchingPlasmaClient
};

#define kDelayAfterPlasmaClientLaunch 10.0
#define kTaskKillDelay 3.0

- (id)init {
	self = [super init];
	if (self) {
		kPrefix = @"/opt/local";
		kDrizzle = [[kPrefix stringByAppendingString:@"/bin/drizzle"] retain];
		kDrizzleForDownload = [[NSString alloc] initWithString:kDrizzle];
		kDrizzleForExtract = [[NSString alloc] initWithString:kDrizzle];
		kPlasmaClient = [[kPrefix stringByAppendingString:@"/bin/PlasmaClient"] retain];
		kPlasmaClientForAuth = [[NSString alloc] initWithString:kPlasmaClient];
		kPlasmaClientForGame = [[NSString alloc] initWithString:kPlasmaClient];
		
		kDataDirectory = [[kPrefix stringByAppendingString:@"/share/mystonline/data"] retain];
		kPythonDirectory = [[kDataDirectory stringByAppendingPathComponent:@"python"] retain];
		kSdlDirectory = [[kDataDirectory stringByAppendingPathComponent:@"SDL"] retain];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(finishedTask:)
													 name:NSTaskDidTerminateNotification
												   object:nil];
		
		step = kStepIdle;
		servers = nil;
		downloadSecureFilesRegex1 = nil;
		downloadSecureFilesRegex2 = nil;
		extractSecureFilesRegex = nil;
	}
	return self;
}

- (void)awakeFromNib {
	[self loadRandomBanner];
	[self populateServerMenu];
	[self loadCurrentServerInfo];
}

- (void)loadRandomBanner {
	NSString *bannerDirectory = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Banners"];
	NSArray *allFiles = [[NSFileManager defaultManager] directoryContentsAtPath:bannerDirectory];
	NSArray *bannerFiles = [allFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.jpg'"]];
	if ([bannerFiles count] > 0) {
		NSString *bannerFile = [bannerDirectory stringByAppendingPathComponent:[bannerFiles objectAtIndex:random() % [bannerFiles count]]];
		NSImage *image = [[NSImage alloc] initByReferencingFile:bannerFile];
		[banner setImage:image];
		[image release];
	}	
}

- (void)populateServerMenu {
	[servers release];
	NSString *serversDirectory = [kDataDirectory stringByAppendingPathComponent:@"servers"];
	NSArray *allFiles = [[NSFileManager defaultManager] directoryContentsAtPath:serversDirectory];
	NSArray *serverFiles = [allFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.ini'"]];
	servers = [[NSMutableArray alloc] init];
	[serverMenu removeAllItems];
	Server *server;
	NSMenuItem *menuItem;
	NSString *defaultServer = [[NSUserDefaults standardUserDefaults] stringForKey:@"server"];
	for (NSString *serverFile in serverFiles) {
		server = [[Server alloc] initWithIniFilename:[serversDirectory stringByAppendingPathComponent:serverFile]];
		menuItem = [[NSMenuItem alloc] initWithTitle:[server displayName] action:@selector(serverMenuChanged:) keyEquivalent:@""];
		[menuItem setTarget:self];
		[[serverMenu menu] addItem:menuItem];
		if ([[server internalName] isEqualToString:defaultServer]) {
			[serverMenu selectItem:menuItem];
		}
		[menuItem release];
		[servers addObject:server];
		[server release];
	}
}

- (void)loadCurrentServerInfo {
	Server *currentServer = [servers objectAtIndex:[serverMenu indexOfSelectedItem]];
	[currentServer showStatusInField:serverStatusLabel];
	
	NSDictionary *login = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"logins"] objectForKey:[currentServer internalName]];
	[usernameField setStringValue:(login ? [login objectForKey:@"username"] : @"")];
	NSString *password = (login ? [login objectForKey:@"password"] : @"");
	[passwordField setStringValue:password];
	[rememberPasswordCheckbox setState:(login ? ([password length] > 0) : NO)];
	
	[createAccountButton setEnabled:([currentServer createAccountUrl] != nil)];
}

- (void)processReceivedData:(NSNotification *)notification {
    NSData *data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	if ([data length] > 0) {
		NSString *dataString = [[NSString alloc] initWithBytes:[data bytes]
														length:[data length]
													  encoding:NSUTF8StringEncoding];
		[taskDataString appendString:dataString];
		[dataString release];
		NSArray *lines = [taskDataString componentsSeparatedByString:@"\n"];
		if ([lines count] > 1) {
			NSString *line;
			NSArray *matches;
			for (int i = 0; i < [lines count] - 1; i++) {
				line = [lines objectAtIndex:i];
				switch (step) {
					case kStepDownloadingSecureFiles:
						if ([downloadSecureFilesRegex1 matchesString:line]) {
							// Downloading file 1 of 59
							matches = [downloadSecureFilesRegex1 capturedSubstringsOfString:line];
							currentFileNumber = [[matches objectAtIndex:1] intValue];
							totalNumberOfFiles = [[matches objectAtIndex:2] intValue];
							bytesDownloadedForThisFile = 0;
							totalBytesForThisFile = 1;
							[progressBar setIndeterminate:NO];
						} else if ([downloadSecureFilesRegex2 matchesString:line]) {
							//    0.5% done. (32768 bytes out of 6357472)
							matches = [downloadSecureFilesRegex2 capturedSubstringsOfString:line];
							bytesDownloadedForThisFile = [[matches objectAtIndex:1] intValue];
							totalBytesForThisFile = [[matches objectAtIndex:2] intValue];
						}
						[progressBar setDoubleValue:0.5 * ((double)(currentFileNumber - 1 + ((double)bytesDownloadedForThisFile / (double)totalBytesForThisFile)) / (double)totalNumberOfFiles)];
						break;
					case kStepExtractingSecureFiles:
						if ([extractSecureFilesRegex matchesString:line]) {
							// Decompiling: Ahnonay.py (file 1 of 503)
							matches = [extractSecureFilesRegex capturedSubstringsOfString:line];
							currentFileNumber = [[matches objectAtIndex:1] intValue];
							totalNumberOfFiles = [[matches objectAtIndex:2] intValue];
							[progressBar setIndeterminate:NO];
						}
						[progressBar setDoubleValue:0.5 + 0.5 * ((double)currentFileNumber / (double)totalNumberOfFiles)];
						break;
				}
			}
			[taskDataString release];
			taskDataString = [[NSMutableString alloc] initWithString:[lines objectAtIndex:[lines count] - 1]];
		}
	}
	[[notification object] readInBackgroundAndNotify];  
}

- (void)finishedTask:(NSNotification *)notification {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(terminateLauncher) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(killTask) object:nil];
	if ([[task standardOutput] respondsToSelector:@selector(fileHandleForReading)]) {
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSFileHandleReadCompletionNotification
													  object:[[task standardOutput] fileHandleForReading]];
	}
	int status = [task terminationStatus];
	[task release];
	[taskDataString release];
	taskDataString = nil;
	if (status == 0 && !cancelled) {
		BOOL hasSecurePythonFiles;
		BOOL hasSecureSdlFiles;
		BOOL isDir;
		switch (step) {
			case kStepAuthenticating: 
				hasSecurePythonFiles = ([[NSFileManager defaultManager] fileExistsAtPath:kPythonDirectory isDirectory:&isDir] && isDir);
				hasSecureSdlFiles = ([[NSFileManager defaultManager] fileExistsAtPath:kSdlDirectory isDirectory:&isDir] && isDir);
				if (hasSecurePythonFiles && hasSecureSdlFiles) {
					[self launchPlasmaClient];
				} else {
					[self downloadSecureFiles];
				}
				break;
			case kStepDownloadingSecureFiles:
				[self extractSecureFiles];
				break;
			case kStepExtractingSecureFiles:
				[self installSecureFiles];
				[self launchPlasmaClient];
				break;
			case kStepLaunchingPlasmaClient:
			default:
				step = kStepIdle;
				[NSApp endSheet:progressPanel];
		}
	} else {
		int failedStep = step;
		step = kStepIdle;
		[NSApp endSheet:progressPanel];
		switch (failedStep) {
			case kStepAuthenticating:
			case kStepLaunchingPlasmaClient:
				switch (status) {
					case 255: {
						NSMutableString *message = [[NSMutableString alloc] initWithString:@"Check that you’ve entered the correct username and password."];
						NSRange range = [[usernameField stringValue] rangeOfString:@"@"];
						if ((range.location == NSNotFound) && [[servers objectAtIndex:[serverMenu indexOfSelectedItem]] isDefaultServer]) {
							[message appendString:@" "];
							[message appendString:[NSString stringWithFormat:@"On the %@ server, your username is your email address.", [[servers objectAtIndex:[serverMenu indexOfSelectedItem]] displayName]]];
						}
						[self showAlertWithTitle:@"Authentication failed"
										 message:message];
						[message release];
						return;
					}
				}
			case kStepDownloadingSecureFiles:
			case kStepExtractingSecureFiles:
				[[NSFileManager defaultManager] removeFileAtPath:tempDirectory handler:nil];
				[tempDirectory release];
				// continue on to show unexpected error message
				break;
		}
		if (!cancelled) {
			[self showAlertWithTitle:@"Unexpected error"
							 message:[NSString stringWithFormat:@"%@ quit unexpectedly with status %d.", [[task launchPath] lastPathComponent], status]];
		}
	}
}

- (void)killTask {
	kill([task processIdentifier], SIGKILL);
}

- (IBAction)cancelButtonClicked:(id)sender {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(terminateLauncher) object:nil];
	[progressBar setIndeterminate:YES];
	[cancelButton setEnabled:NO];
	cancelled = YES;
	[task terminate];
	[self performSelector:@selector(killTask) withObject:nil afterDelay:kTaskKillDelay];
}

- (IBAction)serverMenuChanged:(id)sender {
	[self loadCurrentServerInfo];
	[[NSUserDefaults standardUserDefaults] setValue:[[servers objectAtIndex:[serverMenu indexOfSelectedItem]] internalName]
											 forKey:@"server"];
}

- (void)controlTextDidChange:(NSNotification *)notification {
	NSTextField *field = [notification object];
	if (field == usernameField || field == passwordField) {
		[self saveLogin];
	}
}

- (IBAction)rememberPasswordCheckboxClicked:(id)sender {
	[self saveLogin];
}

- (void)saveLogin {
	Server *currentServer = [servers objectAtIndex:[serverMenu indexOfSelectedItem]];
	
	NSMutableDictionary *logins = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"logins"] mutableCopy];
	if (logins == nil) {
		logins = [NSMutableDictionary dictionary];
	}
	
	NSMutableDictionary *login = [[logins objectForKey:[currentServer internalName]] mutableCopy];
	if (login == nil) {
		login = [NSMutableDictionary dictionary];
	}
	
	[login setObject:[usernameField stringValue]
			  forKey:@"username"];
	[login setObject:([rememberPasswordCheckbox state] ? [passwordField stringValue] : @"")
			  forKey:@"password"];
	
	[logins setObject:login forKey:[currentServer internalName]];
	
	[[NSUserDefaults standardUserDefaults] setObject:logins forKey:@"logins"];
}

- (IBAction)createAccountButtonClicked:(id)sender {
	[[servers objectAtIndex:[serverMenu indexOfSelectedItem]] openCreateAccountUrl];
}

- (IBAction)playButtonClicked:(id)sender {
	[self checkForGameFiles];
}

- (void)checkForGameFiles {
	BOOL isDir;
	if ([[NSFileManager defaultManager] fileExistsAtPath:[kDataDirectory stringByAppendingPathComponent:@"dat"]
											 isDirectory:&isDir] && isDir) {
		[self authenticate];
	} else {
		[self showAlertWithTitle:@"Game files missing" message:@"PlasmaClient needs the Myst Online: URU Live again game data files. Please install the “mystonline-cider” port and run the application to let it download all the game data."];
	}
}

- (void)authenticate {
	step = kStepAuthenticating;
	[self showProgressPanel];
	[self setProgressPanelMessage:@"Authenticating…"];
	task = [[NSTask alloc] init];
	[task setCurrentDirectoryPath:kDataDirectory];
	[task setLaunchPath:kPlasmaClientForAuth];
	[task setArguments:[NSArray arrayWithObjects:@"--server",
						[[servers objectAtIndex:[serverMenu indexOfSelectedItem]] internalName],
						@"--test-auth",
						[usernameField stringValue],
						[passwordField stringValue],
						nil]];
	[task setStandardOutput:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
	[task setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
	[task launch];
}

- (void)downloadSecureFiles {
	if (![[servers objectAtIndex:[serverMenu indexOfSelectedItem]] isDefaultServer]) {
		step = kStepIdle;
		[NSApp endSheet:progressPanel];
		NSArray *defaultServers = [servers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isDefaultServer = YES"]];
		[self showAlertWithTitle:@"Secure game files missing" message:[NSString stringWithFormat:@"PlasmaClient needs the Myst Online: URU Live again secure game data files. PCLauncher can download these files for you, but only if you select the %@ server.", [[defaultServers objectAtIndex:0] displayName]]];
		return;
	}
	step = kStepDownloadingSecureFiles;
	[self setProgressPanelMessage:@"Downloading secure files…"];
	if (downloadSecureFilesRegex1 == nil) downloadSecureFilesRegex1 = [[CSRegex alloc] initWithPattern:@"Downloading file ([0-9]+) of ([0-9]+)" options:0];
	if (downloadSecureFilesRegex2 == nil) downloadSecureFilesRegex2 = [[CSRegex alloc] initWithPattern:@"[[:space:]]*[0-9.]+% done. \\(([0-9]+) bytes out of ([0-9]+)\\)" options:0];
	tempDirectory = [[self makeTempDirectory] retain];
	task = [[NSTask alloc] init];
	[task setLaunchPath:kDrizzleForDownload];
	[task setArguments:[NSArray arrayWithObjects:@"-downloadsecuremoulagainfiles",
						[usernameField stringValue],
						[passwordField stringValue],
						tempDirectory,
						nil]];
	[task setCurrentDirectoryPath:tempDirectory];
	[task setStandardOutput:[NSPipe pipe]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(processReceivedData:)
												 name:NSFileHandleReadCompletionNotification
											   object:[[task standardOutput] fileHandleForReading]];
	taskDataString = [[NSMutableString alloc] init];
	currentFileNumber = 0;
	totalNumberOfFiles = 1;
	bytesDownloadedForThisFile = 0;
	totalBytesForThisFile = 1;
	[[[task standardOutput] fileHandleForReading] readInBackgroundAndNotify];  
	[task launch];
}

- (void)extractSecureFiles {
	step = kStepExtractingSecureFiles;
	[self setProgressPanelMessage:@"Extracting secure files…"];
	if (extractSecureFilesRegex == nil) extractSecureFilesRegex = [[CSRegex alloc] initWithPattern:@"Decompiling: .* \\(file ([0-9]+) of ([0-9]+)\\)" options:0];
	task = [[NSTask alloc] init];
	[task setLaunchPath:kDrizzleForExtract];
	[task setArguments:[NSArray arrayWithObjects:@"-decompilepak",
						[tempDirectory stringByAppendingPathComponent:@"Python/python.pak"],
						[tempDirectory stringByAppendingPathComponent:@"Python/python"],
						@"moul",
						nil]];
	[task setCurrentDirectoryPath:tempDirectory];
	[task setStandardOutput:[NSPipe pipe]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(processReceivedData:)
												 name:NSFileHandleReadCompletionNotification
											   object:[[task standardOutput] fileHandleForReading]];
	taskDataString = [[NSMutableString alloc] init];
	currentFileNumber = 0;
	totalNumberOfFiles = 1;
	[[[task standardOutput] fileHandleForReading] readInBackgroundAndNotify];  
	[task launch];
}

- (void)installSecureFiles {
	[[NSFileManager defaultManager] removeFileAtPath:kPythonDirectory handler:nil];
	[[NSFileManager defaultManager] copyPath:[tempDirectory stringByAppendingPathComponent:@"Python/python"]
									  toPath:kPythonDirectory
									 handler:nil];
	
	[[NSFileManager defaultManager] removeFileAtPath:kSdlDirectory handler:nil];
	[[NSFileManager defaultManager] copyPath:[tempDirectory stringByAppendingPathComponent:@"SDL"]
									  toPath:kSdlDirectory
									 handler:nil];
	
	[[NSFileManager defaultManager] removeFileAtPath:tempDirectory handler:nil];
	[tempDirectory release];
}

- (void)launchPlasmaClient {
	step = kStepLaunchingPlasmaClient;
	[progressBar setIndeterminate:YES];
	[self setProgressPanelMessage:@"Launching PlasmaClient…"];
	[preferencesWindowController save];
	task = [[NSTask alloc] init];
	[task setCurrentDirectoryPath:kDataDirectory];
	[task setLaunchPath:kPlasmaClientForGame];
	[task setArguments:[NSArray arrayWithObjects:@"--server",
						[[servers objectAtIndex:[serverMenu indexOfSelectedItem]] internalName],
						[usernameField stringValue],
						[passwordField stringValue],
						nil]];
	[task setStandardOutput:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
	[task setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
	[task launch];
	[self performSelector:@selector(terminateLauncher) withObject:nil afterDelay:kDelayAfterPlasmaClientLaunch];
}

- (void)terminateLauncher {
	[NSApp endSheet:progressPanel];
	[NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

/*** Progress panel ***/

- (void)showProgressPanel {
	[progressBar setIndeterminate:YES];
	[progressBar setMaxValue:1.0];
	[progressBar startAnimation:self];
	[cancelButton setEnabled:YES];
	cancelled = NO;
	[NSApp beginSheet:progressPanel
	   modalForWindow:loginWindow
		modalDelegate:self
	   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
		  contextInfo:nil];
}

- (void)setProgressPanelMessage:(NSString *)status {
	[progressLabel setStringValue:status];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	[sheet orderOut:self];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:title];
	[alert setInformativeText:message];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:loginWindow
					  modalDelegate:self
					 didEndSelector:nil
						contextInfo:nil];
	[alert release];
}

- (NSString *)makeTempDirectory {
	NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@".XXXXXXXX"]];
	char tempDirCString[PATH_MAX + 1];
	[tempDir getFileSystemRepresentation:tempDirCString maxLength:PATH_MAX];
	char *result = mkdtemp(tempDirCString);
	if (!result) return @"/tmp";
	tempDir = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempDirCString length:strlen(result)];
	if (!tempDir) return @"/tmp";
	return tempDir;
}

- (void)dealloc {
	[kDrizzle release];
	[kDrizzleForDownload release];
	[kDrizzleForExtract release];
	[kPlasmaClient release];
	[kPlasmaClientForAuth release];
	[kPlasmaClientForGame release];
	[kDataDirectory release];
	[kPythonDirectory release];
	[kSdlDirectory release];
	[downloadSecureFilesRegex1 release];
	[downloadSecureFilesRegex2 release];
	[extractSecureFilesRegex release];
	[servers release];
	[super dealloc];
}

@end
