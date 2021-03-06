//
//  ViewController.m
//  RPMLogger
//
//  Created by Greg Paton on 3/2/13.
//  Copyright (c) 2013 Greg Paton. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // set up Bluetooth shield
    bleShield = [[BLE alloc] init];
    [bleShield controlSetup:1];
    bleShield.delegate = (id)self;
    
    // allocate array for RPM data
    RPMs = [[NSMutableArray alloc] init];
    
    // set up graph view
    CPTTheme *theme = [CPTTheme themeNamed:kCPTPlainWhiteTheme];
    graph = [theme newGraph];
    _viewCPTLHV.hostedGraph = graph;
    
    graph.paddingLeft = 0.0;
    graph.paddingTop = 0.0;
    graph.paddingRight = 0.0;
    graph.paddingBottom = 0.0;
    
    plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0) length:CPTDecimalFromFloat(60)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0) length:CPTDecimalFromFloat(2000)];
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    
    CPTXYAxis *x = axisSet.xAxis;
    x.majorIntervalLength = CPTDecimalFromFloat(10);
    x.minorTicksPerInterval = 2;
    x.borderWidth = 0;
    x.labelExclusionRanges = [NSArray arrayWithObjects:
                              [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-100)
                                                           length:CPTDecimalFromFloat(1100)], nil];
    
    CPTXYAxis *y = axisSet.yAxis;
    y.majorIntervalLength = CPTDecimalFromFloat(10);
    y.minorTicksPerInterval = 1;
    y.labelExclusionRanges = [NSArray arrayWithObjects:
                              [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-100)
                                                           length:CPTDecimalFromFloat(6100)], nil];
    
    // set up plot data
    CPTScatterPlot *sp = [[CPTScatterPlot alloc] init];
    sp.identifier = @"RPM";
    sp.dataSource = self;
    sp.delegate = self;
    [graph addPlot:sp toPlotSpace:graph.defaultPlotSpace];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Timer

// Called when scan period is over to connect to the first found peripheral
-(void) connectionTimer:(NSTimer *)timer
{
    if(bleShield.peripherals.count > 0)
    {
        [bleShield connectPeripheral:[bleShield.peripherals objectAtIndex:0]];
    }
    else
    {
        [self.spinner stopAnimating];
    }
}

#pragma mark - BLE 

-(void) bleDidReceiveData:(unsigned char *)data length:(int)length
{
    NSData *OBDData = [NSData dataWithBytes:data length:length];
    NSString *OBDres = [[NSString alloc] initWithData:OBDData encoding:NSUTF8StringEncoding];
    
    // process OBD data
    
    // mode $01
    if ([OBDres length] > 2 && [[OBDres substringToIndex:2] isEqualToString:@"41"]) {
        OBDres = [OBDres substringFromIndex:3];
        // RPM
        if ([OBDres length] > 7 && [[OBDres substringToIndex:2] isEqualToString:@"0C"]) {
            OBDres = [[OBDres substringFromIndex:3] stringByReplacingOccurrencesOfString:@" " withString:@""];
            int size = 0;
            double rpm;
            unsigned dec;
            NSScanner *scan = [NSScanner scannerWithString:OBDres];
            [scan setScanLocation:0];
            [scan scanHexInt:&dec];
            rpm = dec / 4;
            // synchronize access to RPMs array
            @synchronized(RPMs) {
                [RPMs addObject:[NSNumber numberWithFloat:rpm]];
                size = [RPMs count];
            }
            // resize graph area to fit new data
            if (plotSpace.xRange.lengthDouble < size) {
                plotSpace.xRange = [CPTPlotRange
                                    plotRangeWithLocation:CPTDecimalFromFloat(0)
                                    length:CPTDecimalFromFloat(size)];
            }
            [graph reloadData];
        }
        // Speed
        else if ([OBDres length] > 4 && [[OBDres substringToIndex:2] isEqualToString:@"0D"]) {
            
        }
        // Mass Air Flow
        else if ([OBDres length] > 7 && [[OBDres substringToIndex:2] isEqualToString:@"10"]) {
            
        }
        // Throttle Position
        else if ([OBDres length] > 4 && [[OBDres substringToIndex:2] isEqualToString:@"11"]) {
            
        }
        // Fuel Level Input
        else if ([OBDres length] > 4 && [[OBDres substringToIndex:2] isEqualToString:@"2F"]) {
            
        }
    }
    // mode $09
    else if ([OBDres length] > 2 && [[OBDres substringToIndex:2] isEqualToString:@"49"]) {

    }
    else
        printf("%s\n", [OBDres UTF8String]);
}

- (void) bleDidDisconnect
{
    [self.buttonConnect setTitle:@"Connect" forState:UIControlStateNormal];
    
    // stop log thread if it is running
    if ([_buttonStart.titleLabel.text isEqualToString:@"Stop"]) {
        [_buttonStart setTitle:@"Start" forState:UIControlStateNormal];
        [logRPMthread cancel];
    }
}

-(void) bleDidConnect
{
    [self.spinner stopAnimating];
    [self.buttonConnect setTitle:@"Disconnect" forState:UIControlStateNormal];
}

-(void) bleDidUpdateRSSI:(NSNumber *)rssi
{
    //self.labelRSSI.text = rssi.stringValue;
}

- (IBAction)BLEShieldSend:(id)sender
{
    NSString *s;
    NSData *d;
    
    // if not connected scan for devices
    if ([self.buttonConnect.titleLabel.text isEqualToString:@"Connect"])
        [self BLEShieldScan:sender];
    
    if (self.textField.text.length > 16)
        s = [self.textField.text substringToIndex:16];
    else
        s = self.textField.text;
    
    s = [NSString stringWithFormat:@"%@\r\n", s];
    d = [s dataUsingEncoding:NSUTF8StringEncoding];
    
    [bleShield write:d];
    
    [self.textField resignFirstResponder];
}

- (void)BLESendCommand:(NSString*)cmd
{
    NSString *s;
    NSData *d;
    
    // if not connected return
    if ([self.buttonConnect.titleLabel.text isEqualToString:@"Connect"])
        return;
    
    // only send first 16 characters of command
    if (cmd.length > 16)
        s = [cmd substringToIndex:16];
    else
        s = cmd;
    
    s = [NSString stringWithFormat:@"%@\r\n", s];
    d = [s dataUsingEncoding:NSUTF8StringEncoding];
    
    [bleShield write:d];
}

- (IBAction)BLEShieldScan:(id)sender
{
    int timeout = 4;
    
    if (bleShield.activePeripheral)
        if(bleShield.activePeripheral.isConnected)
        {
            [[bleShield CM] cancelPeripheralConnection:[bleShield activePeripheral]];
            return;
        }
    
    if (bleShield.peripherals)
        bleShield.peripherals = nil;
    
    [bleShield findBLEPeripherals:timeout];
    
    [NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
    
    [self.spinner startAnimating];
}

#pragma mark - IBAction

- (IBAction)startLoggingRPM:(id)sender {
    if ([_buttonConnect.titleLabel.text isEqualToString:@"Disconnect"]
        && [_buttonStart.titleLabel.text isEqualToString:@"Start"]) {
        
        [_buttonStart setTitle:@"Stop" forState:UIControlStateNormal];
        
        // allocate and start thread
        logRPMthread = [[NSThread alloc] initWithTarget:self selector:@selector(logRPM) object:nil];
        [logRPMthread start];
    }
    else if ([_buttonStart.titleLabel.text isEqualToString:@"Stop"]) {
        [_buttonStart setTitle:@"Start" forState:UIControlStateNormal];
        
        // stop thread
        [logRPMthread cancel];
    }
}

- (IBAction)refreshGraph:(id)sender {
    [graph reloadData];
}

#pragma mark - Threading

- (void)logRPM {
    int size = 0;
    while ([logRPMthread isCancelled] == NO) {
        [self BLESendCommand:@"01 0c"];
        [NSThread sleepForTimeInterval:0.5];
        
        // synchronize access to RPMs array
        @synchronized(RPMs) {
            while (size < [RPMs count]) {
                printf("%f\n", [[RPMs objectAtIndex:size] doubleValue]);
                ++size;
            }
        }
    }
}

#pragma mark - CorePlot 

- (NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot {
    int val = 0;
    @synchronized(RPMs) {
        val = [RPMs count];
    }
    return val;
}

- (NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum
                recordIndex:(NSUInteger)index {
    // for x simply return index value
    if (fieldEnum == CPTScatterPlotFieldX) {
        return [NSNumber numberWithUnsignedInteger:index];
    }
    // for y return RPM value
    else {
        if ([plot.identifier isEqual:@"RPM"]) {
            double val = 0;
            @synchronized(RPMs) {
                if ([RPMs count] > index)
                    val = [[RPMs objectAtIndex:index] doubleValue];
            }
            return [NSNumber numberWithDouble:val];
        }
    }
    
    return [NSNumber numberWithInt:0];
}

@end
