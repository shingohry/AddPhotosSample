//
//  FirstViewController.m
//  AddPhotosSample
//
//  Created by 平屋真吾 on 2014/11/24.
//  Copyright (c) 2014年 Shingo Hiraya. All rights reserved.
//

#import "FirstViewController.h"

@import Photos;
@import CoreLocation;

static NSString * const AlbumTitle = @"HasLocationInfo";

@interface FirstViewController ()

@property (nonatomic, strong) PHAssetCollection *assetCollection;

@end

@implementation FirstViewController

#pragma mark -  methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self checkAuthorizationStatus];
}

#pragma mark -  methods

- (void)createAlbum
{
    PHFetchOptions *options = [PHFetchOptions new];
    options.predicate = [NSPredicate predicateWithFormat:@"localizedTitle == %@", AlbumTitle];
    PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:options];
    
    if (albums.count > 0) {
        // Album is exist
        self.assetCollection = albums[0];
        [self addAssets];
    } else {
        // Create new album.
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:AlbumTitle];
        } completionHandler:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"Error creating AssetCollection: %@", error);
            } else {
                PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:options];
                self.assetCollection = albums[0];
                [self addAssets];
            }
        }];
    }
}

- (void)addAssets
{
    // Read asset infomation from JSON file
    NSString *path = [[NSBundle mainBundle] pathForResource:@"assetInfo" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:path options:kNilOptions error:nil];
    NSArray *assetInfoList = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil];
    
    for (NSDictionary *assetInfo in assetInfoList) {
        [self addAssetWithAssetInfo:assetInfo];
    }
}

- (void)addAssetWithAssetInfo:(NSDictionary *)assetInfo
{
    __block NSString *localIdentifier;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        // Create PHAsset from UIImage
        NSString *imageName = assetInfo[@"imageName"];
        PHAssetChangeRequest *assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:[UIImage imageNamed:imageName]];
        
        PHObjectPlaceholder *assetPlaceholder = assetChangeRequest.placeholderForCreatedAsset;
        localIdentifier = assetPlaceholder.localIdentifier;
        
        // Add PHAsset to PHAssetCollection
        PHAssetCollectionChangeRequest *assetCollectionChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:self.assetCollection];
        [assetCollectionChangeRequest addAssets:@[assetPlaceholder]];
        
    } completionHandler:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"creating Asset Error: %@", error);
        } else {
            NSLog(@"creating Asset Success");
            PHFetchResult *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier] options:nil];
            PHAsset *asset = assets[0];
            
            NSNumber *latitude = assetInfo[@"latitude"];
            NSNumber *longitude = assetInfo[@"longitude"];
            
            if (latitude && longitude) {
                // add location data
                CLLocation *location = [[CLLocation alloc]initWithLatitude:latitude.doubleValue longitude:longitude.doubleValue];
                if ([asset canPerformEditOperation:PHAssetEditOperationProperties]) {
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        PHAssetChangeRequest *request = [PHAssetChangeRequest changeRequestForAsset:asset];
                        [request setLocation:location];
                    } completionHandler:^(BOOL success, NSError *error) {
                        if (success) {
                            NSLog(@"%s add location data success", __PRETTY_FUNCTION__);
                        }
                    }];
                }
            } else {
                NSLog(@"latitude or longitude value is nil");
            }
        }
    }];
}

- (void)checkAuthorizationStatus
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusAuthorized:
            // The user has explicitly granted your app access to the photo library.
            NSLog(@"%s authorizationStatus is PHAuthorizationStatusAuthorized", __PRETTY_FUNCTION__);
            [self createAlbum];
            break;
            
        case PHAuthorizationStatusNotDetermined:
        {
            // Explicit user permission is required for photo library access, but the user has not yet granted or denied such permission.
            NSLog(@"%s authorizationStatus is PHAuthorizationStatusNotDetermined", __PRETTY_FUNCTION__);
            
            // Requests the user’s permission, if needed, for accessing the Photos library.
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
                [self createAlbum];
            }];
        }
            break;
            
        case PHAuthorizationStatusRestricted:
            NSLog(@"%s authorizationStatus is PHAuthorizationStatusRestricted", __PRETTY_FUNCTION__);
            break;
            
        case PHAuthorizationStatusDenied:
            NSLog(@"%s authorizationStatus is PHAuthorizationStatusDenied", __PRETTY_FUNCTION__);
            break;
    }
}

@end
