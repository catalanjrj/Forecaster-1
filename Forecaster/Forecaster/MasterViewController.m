//
//  MasterViewController.m
//  Forecaster
//
//  Created by Donny Davis on 5/5/16.
//  Copyright © 2016 Donny Davis. All rights reserved.
//

#import "MasterViewController.h"
#import "CityTableViewCell.h"
#import "DetailViewController.h"
#import "AddLocationViewController.h"
#import "Location.h"

@interface MasterViewController () <NSURLSessionDelegate, AddLocationDelegate>

@property NSDictionary *recievedLocationData;
@property NSMutableArray *receivedLocationArray;

// Properties for JSON data received from Google Maps API request
@property NSMutableData *receivedData;
@property NSMutableArray *coordArray;

- (void)getCoordinates:(NSString *)zipCode;
- (void)getForecastlatitude:(float)latitude longitude:(float)longitude;

- (void)updateLocation:(NSDictionary *)locationDataDictionary weather:(NSDictionary *)weatherDataDictionary;
- (void)handleRefresh:(UIRefreshControl *)refreshControl;

@end

@implementation MasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Cities";

    // Do any additional setup after loading the view, typically from a nib.
    
    self.coordArray = [[NSMutableArray alloc]init];
    self.recievedLocationData = [[NSDictionary alloc] init];
    self.receivedLocationArray = [[NSMutableArray alloc] init];
    
    // Hide the separators between cells
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.tableView.backgroundColor = [UIColor colorWithRed:(199/255.0) green:(216/255.0) blue:(224/255.0) alpha:1.0];
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];

    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    [self.refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    
    // Update weather for current cities listed
    NSArray *locationObjects = [self.fetchedResultsController fetchedObjects];
    for (Location *location in locationObjects) {
        [self.receivedLocationArray addObject:location];
        [self getForecastlatitude:[location.latitude floatValue] longitude:[location.longitude floatValue]];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
    [super viewWillAppear:animated];
    
    // Hide empty cells that don't have data
    self.tableView.tableFooterView = [[UIView alloc] init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)insertNewObject:(NSString *)zipCodeString {
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // Call method for the Google API here
    [self getCoordinates:zipCodeString];

}

#pragma mark - retrieve weather information with API

- (void)getForecastlatitude:(float)latitude longitude:(float)longitude{
    
    //trim coordinates for URL
    
    
    //code format with input from coordinates
    NSString * urlString = [NSString stringWithFormat:@"https://api.forecast.io/forecast/5d288b25264d7b5e082c405582ddc873/%f,%f", latitude, longitude];
    
    //OR hard code raleigh address FOR TESTING
    // NSString * urlString = [NSString stringWithFormat:@"https://api.forecast.io/forecast/5d288b25264d7b5e082c405582ddc873/35.7796, -78.6382"];
    
    //create NS URL from string
    NSURL * url = [NSURL URLWithString:urlString];
    
    //configure what part of processor is being used - main Queue is where all UI elements need to happen
    NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    //pragma mark delegate needs to be set
    NSURLSession * session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    //create data task - which downloads from url
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url];
    
    // tell data task whether to start, stop, resume etc
    [dataTask resume];
}

#pragma mark - getCoordinates

// Send query to Google Maps API to get coordinates (latitude & longitude), city, state given input of zip code
- (void)getCoordinates: (NSString *)zipCode {
    

    // Sample Google Maps API call without city name or sensor (not required)
    // https://maps.googleapis.com/maps/api/geocode/json?&components=postal_code:27701
    
    // Create string which puts together api address plus zip code
    NSString * urlString = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?&components=postal_code:%@",zipCode];
    
    // Create NS URL from string
    NSURL * url = [NSURL URLWithString:urlString];
    
    // Configure what part of processor is being used - main Queue is where all UI elements need to happen
    NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession * session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    // Create data task - which downloads from URL
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url];
    
    // Tell data task whether to start, stop, resume etc
    [dataTask resume];
    
}

#pragma mark - Update Location and Weather

- (void)updateLocation:(NSDictionary *)locationDataDictionary weather:(NSDictionary *)weatherDataDictionary {
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *locationEntity = [[self.fetchedResultsController fetchRequest] entity];
    
    Location *locationObject;
    if (locationDataDictionary[@"results"]) {
        locationObject = [NSEntityDescription insertNewObjectForEntityForName:[locationEntity name] inManagedObjectContext:context];
        NSArray *resultsArray = locationDataDictionary[@"results"];
        NSArray *addressComponentsArray = resultsArray[0][@"address_components"];
        locationObject.latitude = resultsArray[0][@"geometry"][@"location"][@"lat"];
        locationObject.longitude = resultsArray[0][@"geometry"][@"location"][@"lng"];
        for (NSDictionary *addressInfo in addressComponentsArray) {
            if ([addressInfo[@"types"][0] isEqualToString:@"postal_code"]) {
                locationObject.zipCode = [NSNumber numberWithInteger:[addressInfo[@"short_name"] integerValue]];
            }
            if ([addressInfo[@"types"][0] isEqualToString:@"locality"]) {
                locationObject.city = addressInfo[@"long_name"];
            }
            if ([addressInfo[@"types"][0] isEqualToString:@"administrative_area_level_1"]) {
                locationObject.state = addressInfo[@"short_name"];
            }
        }
        
    } else if (self.receivedLocationArray) {
        locationObject = self.receivedLocationArray[0];
        [self.receivedLocationArray removeObjectAtIndex:0];
    }
    
    locationObject.temperature = [NSNumber numberWithInteger:[weatherDataDictionary [@"currently"][@"temperature"] integerValue]];
    locationObject.summary = weatherDataDictionary[@"currently"][@"summary"];
    locationObject.apparentTemperature = [NSNumber numberWithInteger:[weatherDataDictionary[@"currently"][@"apparentTemperature"] integerValue]];
    locationObject.image = weatherDataDictionary[@"currently"][@"icon"];
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
}


#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Location *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        [controller setDetailItem:object];
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
        [sender setSelected:NO];
    } else if ([segue.identifier isEqualToString:@"FindCity"]) {
        AddLocationViewController *addLocationVC = (AddLocationViewController *)[segue.destinationViewController topViewController];
        addLocationVC.delegate = self;
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CityTableViewCell *cell = (CityTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"CityCell" forIndexPath:indexPath];
    Location *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    
    [self configureCell:cell withObject:object];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
            
        NSError *error = nil;
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)configureCell:(CityTableViewCell *)cell withObject:(Location *)object {
    NSString *temperatureString = [NSString stringWithFormat:@"%ld℉", [object.temperature integerValue]];
    cell.temperature.text = temperatureString;
    cell.summary.text = object.summary;
    cell.city.text = object.city;
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 10.0;
}

- (void)handleRefresh:(UIRefreshControl *)refreshControl {
    NSArray *locationObjects = [self.fetchedResultsController fetchedObjects];
    
    for (Location *location in locationObjects) {
        [self.receivedLocationArray addObject:location];
        [self getForecastlatitude:[location.latitude floatValue] longitude:[location.longitude floatValue]];
    }
    
//    [self.tableView reloadData];
    [refreshControl endRefreshing];
}


#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *locationEntity = [NSEntityDescription entityForName:@"Location" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:locationEntity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"city" ascending:YES];

    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        default:
            return;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] withObject:anObject];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}


#pragma mark - NSURLSessionDelegate

// Used when we receive data
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    
    // Check to see if receivedData exists
    if(!self.receivedData) {
        // If there is nothing in variable initialize it with received data
        self.receivedData = [[NSMutableData alloc]initWithData:data];
    } else {
        // If it does exist already, append received data
        [self.receivedData appendData:data];
    }
}

// Used when we get an error
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
        didCompleteWithError:(nullable NSError *)error {
    if (!error && self.receivedData) {
        // Puts the data received into mutable arrays and dictionaries
        NSDictionary * jsonResponse = [NSJSONSerialization JSONObjectWithData:self.receivedData options:NSJSONReadingMutableContainers error:nil];
        if (jsonResponse[@"results"]) {
            self.recievedLocationData = [NSDictionary dictionaryWithDictionary:jsonResponse];
            [self getForecastlatitude:[jsonResponse[@"results"][0][@"geometry"][@"location"][@"lat"] floatValue] longitude:[jsonResponse[@"results"][0][@"geometry"][@"location"][@"lng"] floatValue]];
            
        }else if(jsonResponse[@"currently"]){
            [self updateLocation:self.recievedLocationData weather:jsonResponse];
        }
    }
    self.receivedData = nil;
}

// didReceiveResponse implementation
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    completionHandler(NSURLSessionResponseAllow);
}


@end
