//
//  ZLYPhotoManager.h
//  WhaleyRemote
//
//  Created by 周凌宇 on 2016/10/11.
//  Copyright © 2016年 周凌宇. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@class ZLYAlbumModel,ZLYAssetModel;

extern CGFloat const ImageHeight1080P;
extern CGFloat const ImageWidth1080P;

@interface ZLYImageManager : NSObject

@property (nonatomic, strong) PHCachingImageManager *cachingImageManager;

+ (instancetype)manager;

#pragma mark - 参数

@property (nonatomic, assign) BOOL shouldFixOrientation;
/** 默认600像素宽 */
@property (nonatomic, assign) CGFloat photoDefaultMaxWidth;
/** 对照片排序，按修改时间升序，默认是YES。如果设置为NO,最新的照片会显示在最前面，内部的拍照按钮会排在第一个 */
@property (nonatomic, assign) BOOL sortAscendingByModificationDate;
/** 返回YES如果得到了授权 */
- (BOOL)authorizationStatusAuthorized;

#pragma mark - 相簿相关

// 获取『最近添加』/『相机胶卷』/『所有照片』相册
- (void)getCameraRollAlbum:(BOOL)includeVideo
              includeImage:(BOOL)includeImage
                completion:(void (^)(ZLYAlbumModel *model))completion;

// 获取所有相簿
- (void)getAllAlbums:(BOOL)includeVideo
        includeImage:(BOOL)includeImage
          completion:(void (^)(NSArray<ZLYAlbumModel *> *models))completion;

// 根据相册名来返回相应的相册, 如果没有该相册返回 nil
+ (PHAssetCollection *)getAlbumWithName:(NSString *)albumName;

// 向指定名称的相簿保存图片
+ (void)saveImage:(UIImage *)image
      toAlbumName:(NSString *)albumName
       completion:(void (^)(NSError *error))completion;

#pragma mark - 获得 Asset 相关

// 获取 Asset 数组
- (void)getAssetsFromFetchResult:(PHFetchResult *)result
                    includeVideo:(BOOL)includeVideo
                    includeImage:(BOOL)includeImage
                      completion:(void (^)(NSArray<ZLYAssetModel *> *))completion;

// 获得下标为index的单个照片
// 如果索引越界, 在回调中返回 nil
- (void)getAssetFromFetchResult:(PHFetchResult *)result
                        atIndex:(NSInteger)index
                     completion:(void (^)(ZLYAssetModel *))completion;

#pragma mark - 获得照片相关

- (void)getPostImageWithAlbumModel:(ZLYAlbumModel *)model
                        completion:(void (^)(UIImage *postImage))completion;

- (PHImageRequestID)getPhotoWithAsset:(PHAsset *)asset
                           completion:(void (^)(UIImage *photo,NSDictionary *info,BOOL isDegraded))completion;

- (PHImageRequestID)getPhotoWithAsset:(PHAsset *)asset
                           photoWidth:(CGFloat)photoWidth
                           completion:(void (^)(UIImage *photo,NSDictionary *info,BOOL isDegraded))completion;

- (void)getOriginalPhotoWithAsset:(PHAsset *)asset
                       completion:(void (^)(UIImage *photo,NSDictionary *info))completion;

- (void)getOriginalPhotoDataWithAsset:(PHAsset *)asset
                           completion:(void (^)(NSData *data,NSDictionary *info))completion;

// 获得一组照片的大小
- (void)getPhotosBytesWithArray:(NSArray *)photos
                     completion:(void (^)(NSString *totalBytes))completion;

// 保存照片
- (void)savePhotoWithImage:(UIImage *)image
                completion:(void (^)(NSError *error))completion;

#pragma mark - 视频相关

// 获得视频
- (void)getVideoWithAsset:(id)asset
               completion:(void (^)(AVPlayerItem * playerItem, NSDictionary * info))completion;

// 导出视频
- (void)getVideoOutputPathWithAsset:(id)asset
                         completion:(void (^)(NSString *outputPath))completion;

#pragma mark - Other

- (BOOL)isAssetsArray:(NSArray<PHAsset *> *)assets containAsset:(id)asset;

- (BOOL)isCameraRollAlbum:(NSString *)albumName;

+ (BOOL)isHigherThan1080P:(id)asset;

+ (NSString *)getAssetIdentifier:(id)asset;

+ (NSUInteger)widthWithAsset:(id)asset;

+ (NSUInteger)heightWithAsset:(id)asset;

@end
