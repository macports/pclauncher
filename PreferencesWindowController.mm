//
//  PreferencesWindowController.mm
//  PCLauncher
//
//  Created by Ryan Schmidt on 2010-11-04.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Stream/plEncryptedStream.h>
#import <Util/plString.h>

#import "PreferencesWindowController.h"


@implementation PreferencesWindowController

- (id)init {
	self = [super init];
	if (self) {
		graphicsIniFilename = [[@"~/Library/Preferences/Uru Live/Init/graphics.ini" stringByExpandingTildeInPath] retain];
		graphicsSettings = [[NSMutableDictionary alloc] init];
		dirty = NO;
	}
	return self;
}

- (void)awakeFromNib {
	[graphicsSettings removeAllObjects];
	if ([[NSFileManager defaultManager] fileExistsAtPath:graphicsIniFilename]) {
		plEncryptedStream stream(PlasmaVer::pvMoul);
		if (stream.open([graphicsIniFilename fileSystemRepresentation], fmRead, plEncryptedStream::kEncAuto)) {
			NSString *line;
			NSRange separator;
			NSString *key;
			NSString *value;
			while (!stream.eof()) {
				line = [NSString stringWithUTF8String:stream.readLine().cstr()];
				separator = [line rangeOfString:@" "];
				key = [line substringToIndex:separator.location];
				value = [line substringFromIndex:(separator.location + 1)];
				[graphicsSettings setObject:value forKey:key];
			}
			stream.close();
			value = [graphicsSettings valueForKey:@"Graphics.AnisotropicLevel"];
			if (value != nil) [anisotropicFilteringSlider setFloatValue:log2([value floatValue])];
			value = [graphicsSettings valueForKey:@"Graphics.AntiAliasAmount"];
			if (value != nil) [antialiasingSlider setStringValue:value];
			value = [graphicsSettings valueForKey:@"Graphics.Height"];
			if (value != nil) [heightField setStringValue:value];
			value = [graphicsSettings valueForKey:@"Graphics.SetFovY"];
			if (value != nil) [fieldOfViewYSlider setStringValue:value];
			value = [graphicsSettings valueForKey:@"Graphics.Width"];
			if (value != nil) [widthField setStringValue:value];
			value = [graphicsSettings valueForKey:@"Graphics.Windowed"];
			if (value != nil) [windowedRadio selectCellWithTag:[value isEqualToString:@"true"]];
		}
	}
}

- (IBAction)preferencesMenuItemSelected:(id)sender {
	[preferencesWindow makeKeyAndOrderFront:self];
}

- (IBAction)makeDirty:(id)sender {
	dirty = YES;
}

- (void)save {
	NSString *initDir = [graphicsIniFilename stringByDeletingLastPathComponent];
	if (![[NSFileManager defaultManager] fileExistsAtPath:initDir]) {
		NSString *uruLiveDir = [initDir stringByDeletingLastPathComponent];
		if (![[NSFileManager defaultManager] fileExistsAtPath:uruLiveDir]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:uruLiveDir attributes:nil];
		}
		[[NSFileManager defaultManager] createDirectoryAtPath:initDir attributes:nil];
	}
	if (!dirty) return;
	plEncryptedStream stream(PlasmaVer::pvMoul);
	if (!stream.open([graphicsIniFilename fileSystemRepresentation], fmCreate, plEncryptedStream::kEncXtea)) return;
	[graphicsSettings setValue:[NSString stringWithFormat:@"%.0f", ([anisotropicFilteringSlider intValue] > 0 ? exp2([anisotropicFilteringSlider doubleValue]) : 0)] forKey:@"Graphics.AnisotropicLevel"];
	[graphicsSettings setValue:[NSString stringWithFormat:@"%d", [antialiasingSlider intValue]] forKey:@"Graphics.AntiAliasAmount"];
	[graphicsSettings setValue:[NSString stringWithFormat:@"%d", [heightField intValue]] forKey:@"Graphics.Height"];
	[graphicsSettings setValue:[NSString stringWithFormat:@"%d", [fieldOfViewYSlider intValue]] forKey:@"Graphics.SetFovY"];
	[graphicsSettings setValue:[NSString stringWithFormat:@"%d", [widthField intValue]] forKey:@"Graphics.Width"];
	[graphicsSettings setValue:([windowedRadio selectedTag] == 1 ? @"true" : @"false") forKey:@"Graphics.Windowed"];
	/*
	NSArray *lines = [[NSArray alloc] initWithObjects:
					  [NSString stringWithFormat:@"Graphics.Width %d", [widthField intValue]],
					  [NSString stringWithFormat:@"Graphics.Height %d", [heightField intValue]],
					  [NSString stringWithFormat:@"Graphics.SetFovY %d", [fieldOfViewYSlider intValue]],
					  [NSString stringWithFormat:@"Graphics.AnisotropicLevel %.0f", ([anisotropicFilteringSlider intValue] > 0 ? exp2([anisotropicFilteringSlider doubleValue]) : 0)],
					  [NSString stringWithFormat:@"Graphics.AntiAliasAmount %d", [antialiasingSlider intValue]],
					  [NSString stringWithFormat:@"Graphics.Windowed %@", ([windowedRadio selectedTag] == 1 ? @"true" : @"false")],
					  nil];
	for (NSString *line in lines) {
		stream.write([line lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1, [[line stringByAppendingString:@"\n"] UTF8String]);
	}
	*/
	NSArray *keys = [graphicsSettings allKeys];
	NSString *line;
	NSString *key;
	for (int i = 0; i < [keys count]; i++) {
		key = [keys objectAtIndex:i];
		line = [NSString stringWithFormat:@"%@ %@\n", key, [graphicsSettings objectForKey:key]];
		stream.write([line lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [line UTF8String]);
	}
	stream.close();
//	[lines release];
	dirty = NO;
}

- (void)dealloc {
	[graphicsIniFilename release];
	[graphicsSettings release];
	[super dealloc];
}

@end
