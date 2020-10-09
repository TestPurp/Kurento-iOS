// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

#import "NBMPeerConnection.h"
#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCDataChannelConfiguration.h>
#import <NBMSessionDescriptionFactory.h>
#import "NBMLog.h"
#import <WebRTC/RTCIceCandidate.h>

@interface NBMPeerConnection ()

@property (nonatomic, strong) NSMutableArray *queuedRemoteCandidates;

@property (nonatomic, strong) NSMutableArray<RTCIceCandidate *> *cachedRemoteCandidates;

@end

@implementation NBMPeerConnection

- (instancetype)initWithConnection:(RTCPeerConnection *)connection
{
    self = [super init];

    if (self) {
        _peerConnection = connection;
        _isInitiator = YES;
        _iceAttempts = 0;
        _cachedRemoteCandidates = @[].mutableCopy;
    }

    return self;
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    return [self.peerConnection hash];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[NBMPeerConnection class]]) {
        NBMPeerConnection *otherConnection = (NBMPeerConnection *)object;
        return [otherConnection.peerConnection isEqual:self.peerConnection];
    }

    return NO;
}

- (void)dealloc {
    [self close];
}

#pragma mark - cachedRemoteCandidates check
- (BOOL)candidateHasAdded:(RTCIceCandidate *)candidate {
    NSUInteger index = [_cachedRemoteCandidates indexOfObjectPassingTest:^BOOL (RTCIceCandidate *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        if ([obj.sdp isEqualToString:candidate.sdp]
            && obj.sdpMLineIndex == candidate.sdpMLineIndex) {
            if (candidate.sdpMid) {
                if ([candidate.sdpMid isEqualToString:obj.sdpMid]) {
                    return YES;
                }
            }else {
                if (!obj.sdpMid) {
                    return YES;
                }
            }
        }
        return NO;
    }];
    return index != NSNotFound;
}

#pragma mark - Public

- (void)addIceCandidate:(RTCIceCandidate *)candidate
{
    if ([self candidateHasAdded:candidate]) {
        return;
    }
    [_cachedRemoteCandidates addObject:candidate];
    
    BOOL queueCandidates = self.peerConnection == nil || self.peerConnection.signalingState != RTCSignalingStateStable;

    if (queueCandidates) {
        if (!self.queuedRemoteCandidates) {
            self.queuedRemoteCandidates = [NSMutableArray array];
        }
        DDLogVerbose(@"Queued a remote ICE candidate for later.");
        [self.queuedRemoteCandidates addObject:candidate];
    } else {
        DDLogVerbose(@"Adding a remote ICE candidate.");
        [self.peerConnection addIceCandidate:candidate];
    }
}

- (void)drainRemoteCandidates
{
    DDLogVerbose(@"Drain %lu remote ICE candidates.", (unsigned long)[self.queuedRemoteCandidates count]);

    for (RTCIceCandidate *candidate in self.queuedRemoteCandidates) {
        [self.peerConnection addIceCandidate:candidate];
    }
    self.queuedRemoteCandidates = nil;
}

- (void)removeRemoteCandidates
{
    DDLogDebug(@"%s", __PRETTY_FUNCTION__);

    [self.queuedRemoteCandidates removeAllObjects];
    self.queuedRemoteCandidates = nil;
}

- (void)close
{
    RTCMediaStream *localStream = [self.peerConnection.localStreams firstObject];
    if (localStream) {
        [self.peerConnection removeStream:localStream];
    }
    [self.peerConnection close];
    self.cachedRemoteCandidates = nil;
    self.remoteStream = nil;
    self.peerConnection = nil;
}

@end
