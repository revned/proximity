#import "AppController.h"


@implementation AppController


#pragma mark -
#pragma mark Delegate Methods

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[self stopMonitoring];
}

- (void)awakeFromNib
{
	NSBundle *bundle = [NSBundle mainBundle];
	inRangeImage = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource: @"inRange" ofType: @"png"]];
	inRangeAltImage = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource: @"inRangeAlt" ofType: @"png"]];	
	outOfRangeImage = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource: @"outRange" ofType: @"png"]];
	outOfRangeAltImage = [[NSImage alloc] initWithContentsOfFile: [bundle pathForResource: @"outOfRange" ofType: @"png"]];	

	priorStatus = OutOfRange;
	
	[self createMenuBar];
	[self userDefaultsLoad];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[self userDefaultsSave];
	[self stopMonitoring];
	[self startMonitoring];
}


#pragma mark -
#pragma mark AppController Methods

- (void)createMenuBar
{
	NSMenu *myMenu;
	NSMenuItem *menuItem;
	 
	// Menu for status bar item
	myMenu = [[NSMenu alloc] init];
	
	// Prefences menu item
	menuItem = [myMenu addItemWithTitle:@"Preferences" action:@selector(showWindow:) keyEquivalent:@""];
	[menuItem setTarget:self];
	
	// Quit menu item
	[myMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
	
	// Space on status bar
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	[statusItem retain];
	
	// Attributes of space on status bar
	[statusItem setHighlightMode:YES];
	[statusItem setMenu:myMenu];

	[self menuIconOutOfRange];	
}

- (void)handleTimer:(NSTimer *)theTimer
{
	if( [self isInRange] )
	{
		if( priorStatus == OutOfRange )
		{
			priorStatus = InRange;
			
			[self menuIconInRange];
			[self runInRangeScript];
		}
	}
	else
	{
		if( priorStatus == InRange )
		{
			priorStatus = OutOfRange;
			
			[self menuIconOutOfRange];
			[self runOutOfRangeScript];
		}
	}
	
	[self startMonitoring];
}

- (BOOL)isInRange
{
	if( device && [device remoteNameRequest:nil] == kIOReturnSuccess )
		return true;
	
	return false;
}

- (void)menuIconInRange
{	
	[statusItem setImage:inRangeImage];
	[statusItem setAlternateImage:inRangeAltImage];
		
	//[statusItem	setTitle:@"O"];
}

- (void)menuIconOutOfRange
{
	[statusItem setImage:outOfRangeImage];
	[statusItem setAlternateImage:outOfRangeAltImage];

//	[statusItem setTitle:@"X"];
}

- (BOOL)newVersionAvailable
{
	NSURL *url = [NSURL URLWithString:@"http://reduxcomputing.com/download/Proximity.plist"];
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:url];
	NSArray *version = [[dict valueForKey:@"version"] componentsSeparatedByString:@"."];
	
	int newVersionMajor = [[version objectAtIndex:0] intValue];
	int newVersionMinor = [[version objectAtIndex:1] intValue];
	
	if( thisVersionMajor < newVersionMajor || thisVersionMinor < newVersionMinor )
		return YES;
	
	return NO;
}

- (void)runInRangeScript
{
	NSAppleScript *script;
	NSDictionary *errDict;
	NSAppleEventDescriptor *ae;
	
	script = [[NSAppleScript alloc]
			  initWithContentsOfURL:[NSURL fileURLWithPath:[inRangeScriptPath stringValue]]
			  error:&errDict];
	ae = [script executeAndReturnError:&errDict];		
}

- (void)runOutOfRangeScript
{
	NSAppleScript *script;
	NSDictionary *errDict;
	NSAppleEventDescriptor *ae;
	
	script = [[NSAppleScript alloc]
			  initWithContentsOfURL:[NSURL fileURLWithPath:[outOfRangeScriptPath stringValue]] 
			  error:&errDict];
	ae = [script executeAndReturnError:&errDict];	
}

- (void)startMonitoring
{
	if( [monitoringEnabled state] == NSOnState )
	{
		timer = [NSTimer scheduledTimerWithTimeInterval:[timerInterval intValue]
												 target:self
											   selector:@selector(handleTimer:)
											   userInfo:nil
												repeats:NO];
		[timer retain];
	}		
}

- (void)stopMonitoring
{
	[timer invalidate];
}

- (void)userDefaultsLoad
{
	NSUserDefaults *defaults;
	NSData *deviceAsData;
	
	defaults = [NSUserDefaults standardUserDefaults];
	
	// Device
	deviceAsData = [defaults objectForKey:@"device"];
	if( [deviceAsData length] > 0 )
	{
		device = [NSKeyedUnarchiver unarchiveObjectWithData:deviceAsData];
		[device retain];
		[deviceName setStringValue:[NSString stringWithFormat:@"%@ (%@)",
									[device getName], [device getAddressString]]];
		
		if( [self isInRange] )
		{			
			priorStatus = InRange;
			[self menuIconInRange];
		}
		else
		{
			priorStatus = OutOfRange;
			[self menuIconOutOfRange];
		}
	}
	
	//Timer interval
	if( [[defaults stringForKey:@"timerInterval"] length] > 0 )
		[timerInterval setStringValue:[defaults stringForKey:@"timerInterval"]];
	
	// Out of range script path
	if( [[defaults stringForKey:@"outOfRangeScriptPath"] length] > 0 )
		[outOfRangeScriptPath setStringValue:[defaults stringForKey:@"outOfRangeScriptPath"]];
	
	// In range script path
	if( [[defaults stringForKey:@"inRangeScriptPath"] length] > 0 )
		[inRangeScriptPath setStringValue:[defaults stringForKey:@"inRangeScriptPath"]];
	
	// Check for updates on startup
	BOOL updating = [defaults boolForKey:@"updating"];
	if( updating ) {
		[checkUpdatesOnStartup setState:NSOnState];
		if( [self newVersionAvailable] )
		{
			if( NSRunAlertPanel( @"Proximity", @"A new version of Proximity is available for download.",
								@"Close", @"Download", nil, nil ) == NSAlertAlternateReturn )
			{
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://reduxcomputing.com/proximity/"]];
			}
		}
	}
	
	// Monitoring enabled
	BOOL monitoring = [defaults boolForKey:@"enabled"];
	if( monitoring ) {
		[monitoringEnabled setState:NSOnState];
		[self startMonitoring];
	}
	
	// Run scripts on startup
	BOOL startup = [defaults boolForKey:@"executeOnStartup"];
	if( startup )
	{
		[runScriptsOnStartup setState:NSOnState];
		
		if( monitoring )
		{
			if( [self isInRange] ) {
				[self runInRangeScript];
			} else {
				[self runOutOfRangeScript];
			}
		}
	}
	
}

- (void)userDefaultsSave
{
	NSUserDefaults *defaults;
	NSData *deviceAsData;
	
	defaults = [NSUserDefaults standardUserDefaults];
	
	// Monitoring enabled
	BOOL monitoring = ( [monitoringEnabled state] == NSOnState ? TRUE : FALSE );
	[defaults setBool:monitoring forKey:@"enabled"];
	
	// Update checking
	BOOL updating = ( [checkUpdatesOnStartup state] == NSOnState ? TRUE : FALSE );
	[defaults setBool:updating forKey:@"updating"];
	
	// Execute scripts on startup
	BOOL startup = ( [runScriptsOnStartup state] == NSOnState ? TRUE : FALSE );
	[defaults setBool:startup forKey:@"executeOnStartup"];
	
	// Timer interval
	[defaults setObject:[timerInterval stringValue] forKey:@"timerInterval"];
	
	// In range script
	[defaults setObject:[inRangeScriptPath stringValue] forKey:@"inRangeScriptPath"];

	// Out of range script
	[defaults setObject:[outOfRangeScriptPath stringValue] forKey:@"outOfRangeScriptPath"];
		
	// Device
	if( device ) {
		deviceAsData = [NSKeyedArchiver archivedDataWithRootObject:device];
		[defaults setObject:deviceAsData forKey:@"device"];
	}
	
	[defaults synchronize];
}


#pragma mark -
#pragma mark Interface Methods

- (IBAction)changeDevice:(id)sender
{
	IOBluetoothDeviceSelectorController *deviceSelector;
	deviceSelector = [IOBluetoothDeviceSelectorController deviceSelector];
	[deviceSelector runModal];
	
	NSArray *results;
	results = [deviceSelector getResults];
	
	if( !results )
		return;
	
	device = [results objectAtIndex:0];
	[device retain];
	
	[deviceName setStringValue:[NSString stringWithFormat:@"%@ (%@)",
								[device getName],
								[device getAddressString]]];    
}

- (IBAction)checkConnectivity:(id)sender
{
	[progressIndicator startAnimation:nil];
	
	if( [self isInRange] )
	{
		[progressIndicator stopAnimation:nil];
		NSRunAlertPanel( @"Found", @"Device is powered on and in range", nil, nil, nil, nil );
	}
	else
	{
		[progressIndicator stopAnimation:nil];
		NSRunAlertPanel( @"Not Found", @"Device is powered off or out of range", nil, nil, nil, nil );
	}
}

- (IBAction)checkForUpdates:(id)sender
{
	if( [self newVersionAvailable] )
	{
		if( NSRunAlertPanel( @"Proximity", @"A new version of Proximity is available for download.",
							@"Close", @"Download", nil, nil ) == NSAlertAlternateReturn )
		{
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://reduxcomputing.com/proximity/"]];
		}
	}
	else
	{
		NSRunAlertPanel( @"Proximity", @"You have the latest version.", @"Close", nil, nil, nil );
	}
}

- (IBAction)donate:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://reduxcomputing.com/donate.php"]];
}

- (IBAction)enableMonitoring:(id)sender
{
	// See windowWillClose: method
}

- (IBAction)inRangeScriptChange:(id)sender
{
	NSOpenPanel *op = [NSOpenPanel openPanel];
	[op runModalForDirectory:@"~" file:nil types:[NSArray arrayWithObject:@"scpt"]];
	
	NSArray *filenames = [op filenames];
	[inRangeScriptPath setStringValue:[filenames objectAtIndex:0]];	
}

- (IBAction)inRangeScriptClear:(id)sender
{
	[inRangeScriptPath setStringValue:@""];
}

- (IBAction)inRangeScriptTest:(id)sender
{
	[self runInRangeScript];
}

- (IBAction)outOfRangeScriptChange:(id)sender
{
	NSOpenPanel *op = [NSOpenPanel openPanel];
	[op runModalForDirectory:@"~" file:nil types:[NSArray arrayWithObject:@"scpt"]];
	
	NSArray *filenames = [op filenames];
	[outOfRangeScriptPath setStringValue:[filenames objectAtIndex:0]];    
}

- (IBAction)outOfRangeScriptClear:(id)sender
{
	[outOfRangeScriptPath setStringValue:@""];
}

- (IBAction)outOfRangeScriptTest:(id)sender
{
    [self runOutOfRangeScript];
}

- (void)showWindow:(id)sender
{
	[prefsWindow makeKeyAndOrderFront:self];
	[prefsWindow center];
	
	[self stopMonitoring];
}


@end
