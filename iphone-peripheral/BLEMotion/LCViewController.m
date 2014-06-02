//
//  LCViewController.m
//  BLEMotion
//
//  Created by Mirko on 6/1/14.
//  Copyright (c) 2014 LivelyCode. All rights reserved.
//

#import "LCViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define SERVICE_UUID @"E20A39F4-73F5-4BC4-A12F-17D1AD07A961"
#define ATTITUDE_CHARACTERISTIC_UUID @"08590F7E-DB05-467E-8757-72F6FAEB13D4"

#define FPS 30

@interface LCViewController () <CBPeripheralManagerDelegate>

@property CMMotionManager *motionManager;
@property CBPeripheralManager *peripheralManager;
@property CBMutableCharacteristic *attitudeCharacteristic;
@property NSMutableArray *queue;

@property CGFloat roll;
@property CGFloat pitch;
@property CGFloat yaw;

@property (readonly) CBUUID *attitudeCharacteristicUUID;

@end

@implementation LCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.showsDeviceMovementDisplay = YES;
    self.motionManager.deviceMotionUpdateInterval = 1.0 / FPS;
    
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
        CMAttitude *attitude = motion.attitude;
        self.roll = attitude.roll;
        self.pitch = attitude.pitch;
        self.yaw = attitude.yaw;
    }];
    
    _attitudeCharacteristicUUID = [CBUUID UUIDWithString:ATTITUDE_CHARACTERISTIC_UUID];
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    self.queue = [NSMutableArray arrayWithObjects:self.attitudeCharacteristicUUID, nil];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Don't keep it going while we're not showing.
    [self.peripheralManager stopAdvertising];
    
    [super viewWillDisappear:animated];
}

#pragma mark - Peripheral Methods

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    
    NSLog(@"self.peripheralManager powered on.");
    
    CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc] initWithType:self.attitudeCharacteristicUUID
                                                                     properties:CBCharacteristicPropertyNotify
                                                                          value:nil
                                                                    permissions:CBAttributePermissionsReadable];
    
    CBMutableService *service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:SERVICE_UUID]
                                                                       primary:YES];
    
    service.characteristics = @[characteristic];
    
    [self.peripheralManager addService:service];
    
    self.attitudeCharacteristic = characteristic;
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error) {
        NSLog(@"add service error %@", error);
        return;
    }
    NSLog(@"did add service %@", service.UUID);
    [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:SERVICE_UUID]] }];

}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    if (error) {
        NSLog(@"advertising error %@", error);
        return;
    }
    NSLog(@"did start advertising");
    [self sendData];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic");
}

- (CBMutableCharacteristic *)characteristicForUUID:(CBUUID *)uuid
{
    if ([uuid isEqual:self.attitudeCharacteristicUUID]) {
        return self.attitudeCharacteristic;
    }
    return nil;
}

- (NSData *)dataForCharacteristicUUID:(CBUUID *)uuid
{
    CGFloat values[] = {self.pitch, self.roll, self.yaw};
    NSData *data = [NSData dataWithBytes:values length:sizeof(values)];
    return data;
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");
}

- (void)sendData
{
    CBUUID *uuid = self.queue[0];
    [self.queue removeObjectAtIndex:0];
    BOOL didSend = [self sendDataForCharacteristicUUID:uuid];
    if (!didSend) {
        [self.queue insertObject:uuid atIndex:0];
        return;
    }
    [self.queue addObject:uuid];
    [NSTimer scheduledTimerWithTimeInterval:1.0 / FPS target:self selector:@selector(sendData) userInfo:nil repeats:NO];
}

- (BOOL)sendDataForCharacteristicUUID:(CBUUID *)uuid
{
    CBMutableCharacteristic *characteristic = [self characteristicForUUID:uuid];
    NSData *data = [self dataForCharacteristicUUID:uuid];
    BOOL didSend = [self.peripheralManager updateValue:data forCharacteristic:characteristic onSubscribedCentrals:nil];
    return didSend;
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    [self sendData];
}

@end
