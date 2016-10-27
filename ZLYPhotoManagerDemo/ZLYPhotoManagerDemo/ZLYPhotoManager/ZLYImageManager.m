//
//  ZLYPhotoManager.m
//  WhaleyRemote
//
//  Created by 周凌宇 on 2016/10/11.
//  Copyright © 2016年 周凌宇. All rights reserved.
//

#import "ZLYImageManager.h"
#import "ZLYAssetModel.h"

#define iOS7Later ([UIDevice currentDevice].systemVersion.floatValue >= 7.0f)
#define iOS8Later ([UIDevice currentDevice].systemVersion.floatValue >= 8.0f)
#define iOS9Later ([UIDevice currentDevice].systemVersion.floatValue >= 9.0f)
#define iOS9_1Later ([UIDevice currentDevice].systemVersion.floatValue >= 9.1f)

CGFloat const ImageHeight1080P = 1080.0f;
CGFloat const ImageWidth1080P = 1920.0f;

@interface ZLYImageManager ()

@end

@implementation ZLYImageManager

static CGSize AssetGridThumbnailSize;
static CGFloat ZLYScreenWidth;
static CGFloat ZLYScreenScale;

+ (instancetype)manager {
    static ZLYImageManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
        if (iOS8Later) {
            manager.cachingImageManager = [[PHCachingImageManager alloc] init];
            manager.photoDefaultMaxWidth = 600;
        }
        
        ZLYScreenWidth = [UIScreen mainScreen].bounds.size.width;
        // 测试发现，如果scale在plus真机上取到3.0，内存会增大特别多。故这里写死成2.0
        ZLYScreenScale = 2.0;
        if (ZLYScreenWidth > 700) {
            ZLYScreenScale = 1.5;
        }
    });
    return manager;
}

/**
 判断是否获得相片授权

 @return 是否得到了授权
 */
- (BOOL)authorizationStatusAuthorized {
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) return YES;
    return NO;
}

#pragma mark - 相簿相关

/**
 获取『最近添加』/『相机胶卷』/『所有照片』相册
 
 @param includeVideo 是否包含视频
 @param includeImage 是否包含图片
 @param completion   完成回调
 */
- (void)getCameraRollAlbum:(BOOL)includeVideo
              includeImage:(BOOL)includeImage
                completion:(void (^)(ZLYAlbumModel *model))completion {
    __block ZLYAlbumModel *model;
    PHFetchOptions *option = [[PHFetchOptions alloc] init];
    if (!includeVideo)
        option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeImage];
    if (!includeImage)
        option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeVideo];
    
    // option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:self.sortAscendingByModificationDate]];
    option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:self.sortAscendingByModificationDate]];
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    for (PHAssetCollection *collection in smartAlbums) {
        // 有可能是PHCollectionList类的的对象，过滤掉
        if (![collection isKindOfClass:[PHAssetCollection class]]) continue;
        if ([self isCameraRollAlbum:collection.localizedTitle]) {
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:option];
            model = [self modelWithResult:fetchResult name:collection.localizedTitle];
            if (completion) completion(model);
            break;
        }
    }
}

/**
 获取所有相簿
 
 @param includeVideo 是否包含视频
 @param includeImage 是否包含图片
 @param completion   完成回调
 */
- (void)getAllAlbums:(BOOL)includeVideo
        includeImage:(BOOL)includeImage
          completion:(void (^)(NSArray<ZLYAlbumModel *> *models))completion {
    NSMutableArray *albumArr = [NSMutableArray array];
    PHFetchOptions *option = [[PHFetchOptions alloc] init];
    if (!includeVideo)
        option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeImage];
    if (!includeImage)
        option.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeVideo];
    
    // option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:self.sortAscendingByModificationDate]];
    option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"modificationDate" ascending:self.sortAscendingByModificationDate]];
    PHFetchResult *smartAlbums = [PHAssetCollection
                                  fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                  subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    
    for (PHAssetCollection *collection in smartAlbums) {
        // 有可能是PHCollectionList类的的对象，过滤掉
        if (![collection isKindOfClass:[PHAssetCollection class]]) continue;
        PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:option];
        if (fetchResult.count < 1) continue;
        if ([collection.localizedTitle containsString:@"Deleted"] || [collection.localizedTitle isEqualToString:@"最近删除"]) continue;
        if ([self isCameraRollAlbum:collection.localizedTitle]) {
            [albumArr insertObject:[self modelWithResult:fetchResult name:collection.localizedTitle] atIndex:0];
        } else {
            [albumArr addObject:[self modelWithResult:fetchResult name:collection.localizedTitle]];
        }
    }
    for (PHAssetCollection *collection in topLevelUserCollections) {
        // 有可能是PHCollectionList类的的对象，过滤掉
        if (![collection isKindOfClass:[PHAssetCollection class]]) continue;
        PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:option];
        if (fetchResult.count < 1) continue;
        [albumArr addObject:[self modelWithResult:fetchResult name:collection.localizedTitle]];
    }
    if (completion && albumArr.count > 0) completion(albumArr);
}

/**
 根据相册名来返回相应的相册, 如果没有该相册返回 nil
 
 @param albumName 相册名
 
 @return 相册
 */
+ (PHAssetCollection *)getAlbumWithName:(NSString *)albumName {
    PHFetchResult *assetCollections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                               subtype:PHAssetCollectionSubtypeAlbumRegular
                                                                               options:nil];
    if (assetCollections.count == 0) {
        return nil;
    }
    
    __block PHAssetCollection *myAlbum;
    [assetCollections enumerateObjectsUsingBlock:^(PHAssetCollection *album, NSUInteger idx, BOOL *stop) {
        if ([album.localizedTitle isEqualToString:albumName]) {
            myAlbum = album;
            *stop = YES;
        }
    }];
    
    if (!myAlbum) {
        return nil;
    }
    return myAlbum;
}

/**
 向指定名称的相簿保存图片
 albumName 不能为空
 
 @param image           图片
 @param albumName       相簿名
 @param completion      完成回调
 */
+ (void)saveImage:(UIImage *)image
      toAlbumName:(NSString *)albumName
       completion:(void (^)(NSError *error))completion {
    if ([self stringIsEmpty:albumName]) {
        NSAssert(NO, @"albumName 不能为空");
        return;
    }
    [self createAlbumWithName:albumName
                      success:^(NSString *albumLocalIdentifier) {
                          PHFetchResult *fetchResult =[PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[albumLocalIdentifier]
                                                                                                           options:nil];
                          PHAssetCollection *targetAssetCollection = [fetchResult firstObject];
                          [self addNewAssetWithImage:image
                                             toAlbum:targetAssetCollection
                                           onSuccess:^(NSString *ImageId) {
                                               completion(nil);
                                           } onError:^(NSError *error) {
                                               completion(error);
                                           }];
                      } failed:^(NSError *error) {
                          completion(error);
                          NSLog(@"create ablum error : %@ ", error);
                      }];
}

#pragma mark - 获得 Asset 相关

/**
 获取 Asset 数组

 @param result       PHFetchResult
 @param includeVideo 是否包含视频
 @param includeImage 是否包含图片
 @param completion   完成回调
 */
- (void)getAssetsFromFetchResult:(PHFetchResult *)result
                    includeVideo:(BOOL)includeVideo
                    includeImage:(BOOL)includeImage
                      completion:(void (^)(NSArray<ZLYAssetModel *> *))completion {
    NSMutableArray *photoArr = [NSMutableArray array];
    PHFetchResult *fetchResult = (PHFetchResult *)result;
    [fetchResult enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PHAsset *asset = (PHAsset *)obj;
        ZLYAssetModelMediaType type = ZLYAssetModelMediaTypePhoto;
        if (asset.mediaType == PHAssetMediaTypeVideo)      type = ZLYAssetModelMediaTypeVideo;
        else if (asset.mediaType == PHAssetMediaTypeAudio) type = ZLYAssetModelMediaTypeAudio;
        else if (asset.mediaType == PHAssetMediaTypeImage) {
            if (iOS9_1Later) {
                // if (asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive) type = ZLYAssetModelMediaTypeLivePhoto;
            }
        }
        if (!includeVideo && type == ZLYAssetModelMediaTypeVideo) return;
        if (!includeImage && type == ZLYAssetModelMediaTypeAudio) return;
        
        NSString *timeLength = type == ZLYAssetModelMediaTypeVideo ? [NSString stringWithFormat:@"%0.0f",asset.duration] : @"";
        timeLength = [self getNewTimeFromDurationSecond:timeLength.integerValue];
        [photoArr addObject:[ZLYAssetModel modelWithAsset:asset type:type timeLength:timeLength]];
    }];
    if (completion) completion(photoArr);
}

/**
 获得下标为index的单个照片
 如果索引越界, 在回调中返回 nil

 @param result            PHFetchResult
 @param index             索引
 @param completion        完成回调
 */
- (void)getAssetFromFetchResult:(PHFetchResult *)result
                        atIndex:(NSInteger)index
                     completion:(void (^)(ZLYAssetModel *))completion {
    PHFetchResult *fetchResult = (PHFetchResult *)result;
    PHAsset *asset;
    @try {
        asset = fetchResult[index];
    }
    @catch (NSException* e) {
        if (completion) completion(nil);
        return;
    }
    
    ZLYAssetModelMediaType type = ZLYAssetModelMediaTypePhoto;
    if (asset.mediaType == PHAssetMediaTypeVideo)
        type = ZLYAssetModelMediaTypeVideo;
    else if (asset.mediaType == PHAssetMediaTypeAudio)
        type = ZLYAssetModelMediaTypeAudio;
    
    NSString *timeLength = type == ZLYAssetModelMediaTypeVideo ? [NSString stringWithFormat:@"%0.0f",asset.duration] : @"";
    timeLength = [self getNewTimeFromDurationSecond:timeLength.integerValue];
    ZLYAssetModel *model = [ZLYAssetModel modelWithAsset:asset type:type timeLength:timeLength];
    if (completion) completion(model);
}

#pragma mark - 获得照片相关

/**
 获取相簿封面图
 
 @param model      model 对象
 @param completion 完成回调
 */
- (void)getPostImageWithAlbumModel:(ZLYAlbumModel *)model
                        completion:(void (^)(UIImage *))completion {
    id asset = [model.result lastObject];
    if (!self.sortAscendingByModificationDate) {
        asset = [model.result firstObject];
    }
    [[ZLYImageManager manager] getPhotoWithAsset:asset photoWidth:80 completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
        if (completion) completion(photo);
    }];
}

/**
 根据 asset 获取照片

 @param asset      asset 对象
 @param completion 完成回调

 @return PHImageRequestID
 */
- (PHImageRequestID)getPhotoWithAsset:(PHAsset *)asset completion:(void (^)(UIImage *, NSDictionary *, BOOL isDegraded))completion {
    CGFloat fullScreenWidth = ZLYScreenWidth;
    if (fullScreenWidth > self.photoDefaultMaxWidth) {
        fullScreenWidth = self.photoDefaultMaxWidth;
    }
    return [self getPhotoWithAsset:asset photoWidth:fullScreenWidth completion:completion];
}

- (PHImageRequestID)getPhotoWithAsset:(PHAsset *)asset photoWidth:(CGFloat)photoWidth completion:(void (^)(UIImage *, NSDictionary *, BOOL isDegraded))completion {
    CGSize imageSize;
    if (photoWidth < ZLYScreenWidth && photoWidth < self.photoDefaultMaxWidth) {
        imageSize = AssetGridThumbnailSize;
    } else {
        PHAsset *phAsset = (PHAsset *)asset;
        CGFloat aspectRatio = phAsset.pixelWidth / (CGFloat)phAsset.pixelHeight;
        CGFloat pixelWidth = photoWidth * ZLYScreenScale;
        CGFloat pixelHeight = pixelWidth / aspectRatio;
        imageSize = CGSizeMake(pixelWidth, pixelHeight);
    }
    
    // 修复获取图片时出现的瞬间内存过高问题
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
    option.resizeMode = PHImageRequestOptionsResizeModeFast;
    PHImageRequestID imageRequestID = [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:imageSize contentMode:PHImageContentModeAspectFill options:option resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
        if (downloadFinined && result) {
            result = [self fixOrientation:result];
            if (completion) completion(result,info,[[info objectForKey:PHImageResultIsDegradedKey] boolValue]);
        }
        // 从iCloud下载图片
        if ([info objectForKey:PHImageResultIsInCloudKey] && !result) {
            PHImageRequestOptions *option = [[PHImageRequestOptions alloc]init];
            option.networkAccessAllowed = YES;
            option.resizeMode = PHImageRequestOptionsResizeModeFast;
            [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                UIImage *resultImage = [UIImage imageWithData:imageData scale:0.1];
                resultImage = [self scaleImage:resultImage toSize:imageSize];
                if (resultImage) {
                    resultImage = [self fixOrientation:resultImage];
                    if (completion) completion(resultImage,info,[[info objectForKey:PHImageResultIsDegradedKey] boolValue]);
                }
            }];
        }
    }];
    return imageRequestID;
}

/**
 获取原图
 
 @param asset      资源对象
 @param completion 完成回调
 */
- (void)getOriginalPhotoWithAsset:(PHAsset *)asset completion:(void (^)(UIImage *photo,NSDictionary *info))completion {
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc]init];
    option.networkAccessAllowed = YES;
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFit options:option resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
        if (downloadFinined && result) {
            result = [self fixOrientation:result];
            if (completion) completion(result,info);
        }
    }];
}

- (void)getOriginalPhotoDataWithAsset:(id)asset completion:(void (^)(NSData *data,NSDictionary *info))completion {
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc]init];
    option.networkAccessAllowed = YES;
    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
        if (downloadFinined && imageData) {
            if (completion) completion(imageData,info);
        }
    }];
}

/**
 获得一组照片的大小

 @param photos     图片资源
 @param completion 完成回调
 */
- (void)getPhotosBytesWithArray:(NSArray<ZLYAssetModel *> *)photos completion:(void (^)(NSString *totalBytes))completion {
    __block NSInteger dataLength = 0;
    __block NSInteger assetCount = 0;
    for (NSInteger i = 0; i < photos.count; i++) {
        ZLYAssetModel *model = photos[i];
        [[PHImageManager defaultManager] requestImageDataForAsset:model.asset options:nil resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            if (model.type != ZLYAssetModelMediaTypeVideo) dataLength += imageData.length;
            assetCount ++;
            if (assetCount >= photos.count) {
                NSString *bytes = [self getBytesFromDataLength:dataLength];
                if (completion) completion(bytes);
            }
        }];
    }
}

- (void)savePhotoWithImage:(UIImage *)image completion:(void (^)(NSError *error))completion {
    PHAssetCollection *album;
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                                          subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    for (PHAssetCollection *collection in smartAlbums) {
        if (![collection isKindOfClass:[PHAssetCollection class]]) continue;
        if ([self isCameraRollAlbum:collection.localizedTitle]) {
            album = collection;
            break;
        }
    }
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
        PHObjectPlaceholder *placeHolder = [createAssetRequest placeholderForCreatedAsset];
        [albumChangeRequest addAssets:@[placeHolder]];
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (success && completion) {
                completion(nil);
            } else if (error) {
                NSLog(@"保存照片出错:%@",error.localizedDescription);
                if (completion) {
                    completion(error);
                }
            }
        });
    }];
}

#pragma mark - 视频相关

// 获取视频
- (void)getVideoWithAsset:(id)asset completion:(void (^)(AVPlayerItem * _Nullable, NSDictionary * _Nullable))completion {
    [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:nil resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
        if (completion) completion(playerItem,info);
    }];
}

// 导出视频
- (void)getVideoOutputPathWithAsset:(id)asset completion:(void (^)(NSString *outputPath))completion {
    PHVideoRequestOptions* options = [[PHVideoRequestOptions alloc] init];
    options.version = PHVideoRequestOptionsVersionOriginal;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    options.networkAccessAllowed = YES;
    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset* avasset, AVAudioMix* audioMix, NSDictionary* info){
        // NSLog(@"Info:\n%@",info);
        AVURLAsset *videoAsset = (AVURLAsset*)avasset;
        // NSLog(@"AVAsset URL: %@",myAsset.URL);
        [self startExportVideoWithVideoAsset:videoAsset completion:completion];
    }];
}

#pragma mark - Other

/**
 判断指定assets数组是否包含这个asset
 
 @param assets 资源数组
 @param asset  指定资源
 
 @return 是否包含
 */
- (BOOL)isAssetsArray:(NSArray<PHAsset *> *)assets containAsset:(id)asset {
    return [assets containsObject:asset];
}

- (BOOL)isCameraRollAlbum:(NSString *)albumName {
    NSString *versionStr = [[UIDevice currentDevice].systemVersion stringByReplacingOccurrencesOfString:@"." withString:@""];
    if (versionStr.length <= 1) {
        versionStr = [versionStr stringByAppendingString:@"00"];
    } else if (versionStr.length <= 2) {
        versionStr = [versionStr stringByAppendingString:@"0"];
    }
    CGFloat version = versionStr.floatValue;
    // 目前已知8.0.0 - 8.0.2系统，拍照后的图片会保存在最近添加中
    if (version >= 800 && version <= 802) {
        return [albumName isEqualToString:@"最近添加"] || [albumName isEqualToString:@"Recently Added"];
    } else {
        return [albumName isEqualToString:@"Camera Roll"] || [albumName isEqualToString:@"相机胶卷"] || [albumName isEqualToString:@"所有照片"] || [albumName isEqualToString:@"All Photos"];
    }
}

+ (BOOL)isHigherThan1080P:(id)asset {
    PHAsset *as = (PHAsset *)asset;
    if (as.pixelWidth < ImageWidth1080P|| as.pixelHeight < ImageHeight1080P) {
        return NO;
    } else {
        return YES;
    }
    return NO;
}

+ (NSString *)getAssetIdentifier:(id)asset {
    PHAsset *phAsset = (PHAsset *)asset;
    return phAsset.localIdentifier;
}

+ (NSUInteger)widthWithAsset:(id)asset {
    PHAsset *as = (PHAsset *)asset;
    return as.pixelWidth;
    return 0;
}

+ (NSUInteger)heightWithAsset:(id)asset {
    PHAsset *as = (PHAsset *)asset;
    return as.pixelHeight;
    return 0;
}


/**
 根据指定名字新建相册，如果存在则返回该相册localIdentifier，不存在则生成指定名字的相册并返回localIdentifier.

 @param name      指定相册名
 @param success   成功回调
 @param failed    失败回调
 */
+ (void)createAlbumWithName:(NSString *)name
                 success:(void(^)(NSString *albumLocalIdentifier))success
                   failed:(void(^)(NSError *error)) failed {
    PHAssetCollection *ablumToMake = [self getAlbumWithName:name];
    if (!ablumToMake) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCollectionChangeRequest *createAlbumRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:name];
            [createAlbumRequest placeholderForCreatedAssetCollection];
        } completionHandler:^(BOOL isSuccess, NSError *error) {
            if (error) {
                failed(error);
            } else {
                success([self getAlbumWithName:name].localIdentifier);
            }
        }];
    } else {
        success(ablumToMake.localIdentifier);
    }
}

#pragma mark - Private

- (ZLYAlbumModel *)modelWithResult:(id)result name:(NSString *)name{
    ZLYAlbumModel *model = [[ZLYAlbumModel alloc] init];
    model.result = result;
    model.name = name;
    PHFetchResult *fetchResult = (PHFetchResult *)result;
    model.count = fetchResult.count;
    return model;
}

- (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)size {
    if (image.size.width > size.width) {
        UIGraphicsBeginImageContext(size);
        [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return newImage;
    } else {
        return image;
    }
}

- (UIImage *)fixOrientation:(UIImage *)aImage {
    if (!self.shouldFixOrientation) return aImage;
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

+ (BOOL)stringIsEmpty:(NSString *)string {
    if (string == nil) {
        return YES;
    }
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([string isEqualToString:@""]) {
        return YES;
    }
    return NO;
}

- (NSString *)getNewTimeFromDurationSecond:(NSInteger)duration {
    NSString *newTime;
    if (duration < 10) {
        newTime = [NSString stringWithFormat:@"0:0%zd",duration];
    } else if (duration < 60) {
        newTime = [NSString stringWithFormat:@"0:%zd",duration];
    } else {
        NSInteger min = duration / 60;
        NSInteger sec = duration - (min * 60);
        if (sec < 10) {
            newTime = [NSString stringWithFormat:@"%zd:0%zd",min,sec];
        } else {
            newTime = [NSString stringWithFormat:@"%zd:%zd",min,sec];
        }
    }
    return newTime;
}

- (NSString *)getBytesFromDataLength:(NSInteger)dataLength {
    NSString *bytes;
    if (dataLength >= 0.1 * (1024 * 1024)) {
        bytes = [NSString stringWithFormat:@"%0.1fM",dataLength/1024/1024.0];
    } else if (dataLength >= 1024) {
        bytes = [NSString stringWithFormat:@"%0.0fK",dataLength/1024.0];
    } else {
        bytes = [NSString stringWithFormat:@"%zdB",dataLength];
    }
    return bytes;
}

- (void)startExportVideoWithVideoAsset:(AVURLAsset *)videoAsset completion:(void (^)(NSString *outputPath))completion {
    // Find compatible presets by video asset.
    NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:videoAsset];
    
    // Begin to compress video
    // Now we just compress to low resolution if it supports
    // If you need to upload to the server, but server does't support to upload by streaming,
    // You can compress the resolution to lower. Or you can support more higher resolution.
    if ([presets containsObject:AVAssetExportPreset640x480]) {
        AVAssetExportSession *session = [[AVAssetExportSession alloc]initWithAsset:videoAsset presetName:AVAssetExportPreset640x480];
        
        NSDateFormatter *formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
        NSString *outputPath = [NSHomeDirectory() stringByAppendingFormat:@"/tmp/output-%@.mp4", [formater stringFromDate:[NSDate date]]];
        NSLog(@"video outputPath = %@",outputPath);
        session.outputURL = [NSURL fileURLWithPath:outputPath];
        
        // Optimize for network use.
        session.shouldOptimizeForNetworkUse = true;
        
        NSArray *supportedTypeArray = session.supportedFileTypes;
        if ([supportedTypeArray containsObject:AVFileTypeMPEG4]) {
            session.outputFileType = AVFileTypeMPEG4;
        } else if (supportedTypeArray.count == 0) {
            NSLog(@"No supported file types 视频类型暂不支持导出");
            return;
        } else {
            session.outputFileType = [supportedTypeArray objectAtIndex:0];
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[NSHomeDirectory() stringByAppendingFormat:@"/tmp"]]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[NSHomeDirectory() stringByAppendingFormat:@"/tmp"] withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        // Begin to export video to the output path asynchronously.
        [session exportAsynchronouslyWithCompletionHandler:^(void) {
            switch (session.status) {
                case AVAssetExportSessionStatusUnknown:
                    NSLog(@"AVAssetExportSessionStatusUnknown"); break;
                case AVAssetExportSessionStatusWaiting:
                    NSLog(@"AVAssetExportSessionStatusWaiting"); break;
                case AVAssetExportSessionStatusExporting:
                    NSLog(@"AVAssetExportSessionStatusExporting"); break;
                case AVAssetExportSessionStatusCompleted: {
                    NSLog(@"AVAssetExportSessionStatusCompleted");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(outputPath);
                        }
                    });
                }  break;
                case AVAssetExportSessionStatusFailed:
                    NSLog(@"AVAssetExportSessionStatusFailed"); break;
                default: break;
            }
        }];
    }
}

+ (void)addNewAssetWithImage:(UIImage *)image
                     toAlbum:(PHAssetCollection *)album
                   onSuccess:(void(^)(NSString *ImageId))onSuccess
                     onError:(void(^)(NSError *error))onError {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
        PHObjectPlaceholder *placeHolder = [createAssetRequest placeholderForCreatedAsset];
        [albumChangeRequest addAssets:@[placeHolder]];
        if (placeHolder) {
            onSuccess(placeHolder.localIdentifier);
        }
    } completionHandler:^(BOOL success, NSError *error) {
        if (error) {
            onError(error);
        }
    }];
}

@end
