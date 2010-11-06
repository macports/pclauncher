//
//  PCLauncherAppDelegate.m
//  PCLauncher
//
//  Created by Ryan Schmidt on 2010-10-26.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PCLauncherAppDelegate.h"

@implementation PCLauncherAppDelegate

@synthesize loginWindow;
@synthesize preferencesWindowController;

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	[loginWindow makeKeyAndOrderFront:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
	return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	[preferencesWindowController save];
}

@end
