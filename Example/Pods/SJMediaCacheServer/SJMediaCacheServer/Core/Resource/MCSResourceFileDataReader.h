//
//  MCSResourceFileDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceDefines.h"
@class MCSResource;

NS_ASSUME_NONNULL_BEGIN

@interface MCSResourceFileDataReader : NSObject<MCSResourceDataReader>
- (instancetype)initWithResource:(MCSResource *)resource range:(NSRange)range path:(NSString *)path readRange:(NSRange)readRange delegate:(id<MCSResourceDataReaderDelegate>)delegate;

- (void)prepare;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) NSUInteger availableLength;
@property (nonatomic, readonly) NSUInteger offset;
@property (nonatomic, readonly) BOOL isPrepared;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (BOOL)seekToOffset:(NSUInteger)offset;
- (void)close;

@end

NS_ASSUME_NONNULL_END
