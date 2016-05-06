//
//  DetailViewController.m
//  Forecaster
//
//  Created by Donny Davis on 5/5/16.
//  Copyright © 2016 Donny Davis. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController ()

@end

@implementation DetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem {
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
            
        // Update the view.
        [self configureView];
    }
}

- (void)configureView {
    // Update the user interface for the detail item.
    if (self.detailItem) {
        
        self.weatherLabel.text = [[self.detailItem valueForKey:@"summary"]description];
    self.temperatureLabel.text = [[self.detailItem valueForKey:@"temperature"]description];
        self.feelsLikeTempLabel.text = [[self.detailItem valueForKey:@"apparentTemperature"]description];
        
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.currentLabel.text =@"CURRENTLY";
    
    
    // Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
