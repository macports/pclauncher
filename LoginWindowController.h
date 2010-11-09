//
//  LoginWindowController.h
//
//  Created by Ryan Schmidt on 2010-10-26.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CSRegex.h"
#import "PreferencesWindowController.h"
#import "Server.h"

@interface LoginWindowController : NSObject {
	NSString *kPrefix;
	NSString *kDrizzle;
	NSString *kDrizzleForDownload;
	NSString *kDrizzleForExtract;
	NSString *kPlasmaClient;
	NSString *kPlasmaClientForAuth;
	NSString *kPlasmaClientForGame;
	NSString *kDataDirectory;
	NSString *kPythonDirectory;
	NSString *kSdlDirectory;
	
	IBOutlet id loginWindow;
	IBOutlet id banner;
	IBOutlet id serverStatusLabel;
	IBOutlet id serverMenu;
	IBOutlet id usernameField;
	IBOutlet id passwordField;
	IBOutlet id rememberPasswordCheckbox;
	IBOutlet id createAccountButton;
	IBOutlet id playButton;
	
	IBOutlet id progressPanel;
	IBOutlet id progressLabel;
	IBOutlet id progressBar;
	IBOutlet id cancelButton;
	
	IBOutlet id preferencesWindowController;

	int step;
	NSMutableArray *servers;
	NSTask *task;
	NSMutableString *taskDataString;
	NSString *tempDirectory;
	CSRegex *downloadSecureFilesRegex1;
	CSRegex *downloadSecureFilesRegex2;
	CSRegex *extractSecureFilesRegex;
	int currentFileNumber;
	int totalNumberOfFiles;
	int bytesDownloadedForThisFile;
	int totalBytesForThisFile;
	BOOL cancelled;
}

- (void)loadRandomBanner;
- (void)populateServerMenu;
- (void)loadCurrentServerInfo;
- (void)processReceivedData:(NSNotification *)notification;
- (void)finishedTask:(NSNotification *)notification;
- (void)killTask;

- (IBAction)cancelButtonClicked:(id)sender;
- (IBAction)serverMenuChanged:(id)sender;
- (IBAction)rememberPasswordCheckboxClicked:(id)sender;
- (void)saveLogin;
- (IBAction)createAccountButtonClicked:(id)sender;
- (IBAction)playButtonClicked:(id)sender;
- (void)checkForGameFiles;
- (void)authenticate;
- (void)downloadSecureFiles;
- (void)extractSecureFiles;
- (void)installSecureFiles;
- (void)launchPlasmaClient;
- (void)terminateLauncher;

- (void)showProgressPanel;
- (void)setProgressPanelMessage:(NSString *)status;
- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;

- (NSString *)makeTempDirectory;

@end
