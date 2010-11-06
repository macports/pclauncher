//
//  PreferencesWindowController.h
//  PCLauncher
//
//  Created by Ryan Schmidt on 2010-11-04.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PreferencesWindowController : NSObject {
	IBOutlet id preferencesWindow;
	IBOutlet id widthField;
	IBOutlet id heightField;
	IBOutlet id windowedRadio;
	IBOutlet id fieldOfViewYSlider;
	IBOutlet id antialiasingSlider;
	IBOutlet id anisotropicFilteringSlider;
	
	NSString *graphicsIniFilename;
	NSMutableDictionary *graphicsSettings;
	BOOL dirty;
}

- (IBAction)preferencesMenuItemSelected:(id)sender;
- (IBAction)makeDirty:(id)sender;
- (void)save;

@end
