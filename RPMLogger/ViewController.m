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
    
    bleShield = [[BLE alloc] init];
    [bleShield controlSetup:1];
    bleShield.delegate = (id)self;
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

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

-(void) bleDidReceiveData:(unsigned char *)data length:(int)length
{
    NSData *d = [NSData dataWithBytes:data length:length];
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    self.label.text = s;
}

- (void) bleDidDisconnect
{
    [self.buttonConnect setTitle:@"Connect" forState:UIControlStateNormal];
}

-(void) bleDidConnect
{
    [self.spinner stopAnimating];
    [self.buttonConnect setTitle:@"Disconnect" forState:UIControlStateNormal];
}

-(void) bleDidUpdateRSSI:(NSNumber *)rssi
{
    self.labelRSSI.text = rssi.stringValue;
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

- (IBAction)startLoggingRPM:(id)sender {
    if ([_buttonStart.titleLabel.text isEqualToString:@"Start"]) {
        logRPMthread = [[NSThread alloc] initWithTarget:self selector:@selector(logRPM) object:nil];
        [_buttonStart setTitle:@"Stop" forState:UIControlStateNormal];
        [logRPMthread start];
    }
    else {
        [logRPMthread cancel];
        [_buttonStart setTitle:@"Start" forState:UIControlStateNormal];
    }
}

- (void)logRPM {
    while ([logRPMthread isCancelled] == NO) {
        printf("THREAD\n");
        [NSThread sleepForTimeInterval:1];
    }
}

@end
