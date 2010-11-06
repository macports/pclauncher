//
//  PCLauncherAppDelegate.h
//  PCLauncher
//
//  Created by Ryan Schmidt on 2010-10-26.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PreferencesWindowController.h"

@interface PCLauncherAppDelegate : NSObject {
    NSWindow *loginWindow;
	PreferencesWindowController *preferencesWindowController;
}

@property (assign) IBOutlet NSWindow *loginWindow;
@property (assign) IBOutlet PreferencesWindowController *preferencesWindowController;

@end
