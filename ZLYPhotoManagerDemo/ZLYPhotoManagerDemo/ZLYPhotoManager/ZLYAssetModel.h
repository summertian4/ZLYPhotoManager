//
//  ZLYAssetModel.h
//  WhaleyRemote
//
//  Created by 周凌宇 on 2016/10/11.
//  Copyright © 2016年 周凌宇. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef enum : NSUInteger {
    ZLYAssetModelMediaTypePhoto = 0,
    ZLYAssetModelMediaTypeLivePhoto,
    ZLYAssetModelMediaTypeVideo,
    ZLYAssetModelMediaTypeAudio
} ZLYAssetModelMediaType;

#pragma mark - ======================= ZLYAssetModel =======================

@class PHAsset;

@interface ZLYAssetModel : NSObject

@property (nonatomic, strong) PHAsset *asset;
@property (nonatomic, assign) ZLYAssetModelMediaType type;

/** 如果资源是视频，视频长度 */
@property (nonatomic, copy) NSString *timeLength;

/// 用一个PHAsset/ALAsset实例，初始化一个照片模型
+ (instancetype)modelWithAsset:(id)asset type:(ZLYAssetModelMediaType)type;
+ (instancetype)modelWithAsset:(id)asset type:(ZLYAssetModelMediaType)type timeLength:(NSString *)timeLength;

@end

#pragma mark - ======================= ZLYAlbumModel =======================

@class PHFetchResult;

@interface ZLYAlbumModel : NSObject


/** 相簿名 */
@property (nonatomic, strong) NSString *name;
/** 相片数量 */
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, strong) PHFetchResult *result;

@property (nonatomic, strong) NSArray<ZLYAssetModel *> *models;
@end
