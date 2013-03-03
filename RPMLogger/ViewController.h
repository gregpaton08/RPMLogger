//
//  ViewController.h
//  RPMLogger
//
//  Created by Greg Paton on 3/2/13.
//  Copyright (c) 2013 Greg Paton. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLE.h"

@interface ViewController : UIViewController {
    BLE *bleShield;
    
    NSThread *logRPMthread;
}

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UILabel *labelRSSI;
@property (weak, nonatomic) IBOutlet UIButton *buttonConnect;
@property (weak, nonatomic) IBOutlet UIButton *buttonStart;

@end
