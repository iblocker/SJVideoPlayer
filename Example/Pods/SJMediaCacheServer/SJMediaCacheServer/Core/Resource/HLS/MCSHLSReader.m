//
//  MCSHLSReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSReader.h"
#import "MCSHLSResource.h"
#import "MCSHLSIndexDataReader.h"
#import "MCSHLSTSDataReader.h"
#import "MCSFileManager.h"
#import "MCSLogger.h"
#import "MCSHLSResource.h"
#import "MCSResourceManager.h"
#import "MCSError.h"

@interface MCSHLSReader ()<NSLocking, MCSResourceDataReaderDelegate> {
    dispatch_semaphore_t _semaphore;
}
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic, weak, nullable) MCSHLSResource *resource;
@property (nonatomic, strong, nullable) NSURLRequest *request;

@property (nonatomic, strong, nullable) id<MCSHLSDataReader> reader;
@property (nonatomic) NSUInteger offset;
@end

@implementation MCSHLSReader
@synthesize readDataDecoder = _readDataDecoder;

- (instancetype)initWithResource:(__weak MCSHLSResource *)resource request:(NSURLRequest *)request {
    self = [super init];
    if ( self ) {
        _networkTaskPriority = 1.0;
        _resource = resource;
        _request = request;
        _semaphore = dispatch_semaphore_create(1);
        [_resource readWrite_retain];
        [MCSResourceManager.shared reader:self willReadResource:resource];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(willRemoveResource:) name:MCSResourceManagerWillRemoveResourceNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_resource readWrite_release];
    [MCSResourceManager.shared reader:self didEndReadResource:_resource];
    if ( !_isClosed ) [self close];
    MCSLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (void)willRemoveResource:(NSNotification *)note {
    MCSResource *resource = note.userInfo[MCSResourceManagerUserInfoResourceKey];
    if ( resource == _resource && !self.isClosed )  {
        [self lock];
        [self _close];
        [self unlock];
        [_delegate reader:self anErrorOccurred:[NSError mcs_errorForRemovedResource:_request.URL]];
    }
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
        MCSLog(@"%@: <%p>.prepare { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);

        
        _isCalledPrepare = YES;
        
        if ( [_request.URL.absoluteString containsString:@".m3u8"] ) {
            _reader = [MCSHLSIndexDataReader.alloc initWithResource:_resource URL:_request.URL];
        }
        else {
            NSAssert(_resource.parser != nil, @"`parser`不能为nil!");
            _reader = [MCSHLSTSDataReader.alloc initWithResource:_resource request:_request networkTaskPriority:_networkTaskPriority];
        }
        
        _reader.delegate = self;
        [_reader prepare];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    [self lock];
    @try {
        if ( _isClosed || _reader.isDone )
            return nil;
        
        NSData *data = [_reader readDataOfLength:length];
        if ( _readDataDecoder != nil ) data = _readDataDecoder(_request, _offset, data);
        _offset += data.length;
        return data;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        if ( self.reader.isDone ) {
            MCSLog(@"%@: <%p>.done { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
            [self _close];
        }
        [self unlock];
    }
}

- (void)close {
    [self lock];
    @try {
        [self _close];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
    
//    MCSLog(@"%@: <%p>.close { range: %@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_request.mcs_range));
}

- (BOOL)isReadingEndOfData {
    [self lock];
    @try {
        return _reader.isDone;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

@synthesize isClosed = _isClosed;
- (BOOL)isClosed {
    [self lock];
    @try {
        return _isClosed;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (id<MCSResourceResponse>)response {
    [self lock];
    @try {
        return _reader.response;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)_close {
    if ( _isClosed )
        return;
    
    _isClosed = YES;
    [_reader close];
    
    MCSLog(@"%@: <%p>.close { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
}

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<MCSResourceDataReader>)reader {
    [self lock];
    _isPrepared = YES;
    if ( [reader isKindOfClass:MCSHLSIndexDataReader.class] ) {
        MCSHLSParser *parser = [(MCSHLSIndexDataReader *)reader parser];
        if ( parser != nil && _resource.parser != parser )
            _resource.parser = parser;
    }
    [self unlock];
    [self.delegate readerPrepareDidFinish:self];
}
- (void)readerHasAvailableData:(id<MCSResourceDataReader>)reader {
    [self.delegate readerHasAvailableData:self];
}
- (void)reader:(id<MCSResourceDataReader>)reader anErrorOccurred:(NSError *)error {
    [self.delegate reader:self anErrorOccurred:error];
}
@end
