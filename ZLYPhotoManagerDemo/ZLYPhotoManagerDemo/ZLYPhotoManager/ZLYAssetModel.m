//
//  ZLYAssetModel.m
//  WhaleyRemote
//
//  Created by 周凌宇 on 2016/10/11.
//  Copyright © 2016年 周凌宇. All rights reserved.
//

#import "ZLYAssetModel.h"
#import "ZLYImageManager.h"

@implementation ZLYAssetModel

+ (instancetype)modelWithAsset:(id)asset type:(ZLYAssetModelMediaType)type{
    ZLYAssetModel *model = [[ZLYAssetModel alloc] init];
    model.asset = asset;
    model.type = type;
    return model;
}

+ (instancetype)modelWithAsset:(id)asset type:(ZLYAssetModelMediaType)type timeLength:(NSString *)timeLength {
    ZLYAssetModel *model = [self modelWithAsset:asset type:type];
    model.timeLength = timeLength;
    return model;
}

@end

@implementation ZLYAlbumModel

- (void)setResult:(id)result {
    _result = result;
    BOOL includeImage = [[[NSUserDefaults standardUserDefaults] objectForKey:@"zly_allowPickingImage"] isEqualToString:@"1"];
    BOOL includeVideo = [[[NSUserDefaults standardUserDefaults] objectForKey:@"zly_allowPickingVideo"] isEqualToString:@"1"];
    [[ZLYImageManager manager] getAssetsFromFetchResult:result includeVideo:includeVideo includeImage:includeImage completion:^(NSArray<ZLYAssetModel *> *models) {
        _models = models;
    }];
}

@end
