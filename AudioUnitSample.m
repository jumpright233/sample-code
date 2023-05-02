#import "AudioUnitSample.h"
@import AudioUnit;

#define SAMPLE_RATE             (44100)

static OSStatus audioCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                              UInt32 inNumberFrames, AudioBufferList *ioData);


@interface AudioUnitSample()

@property (nonatomic) AudioUnit audioUnit;
@property (nonatomic) BOOL isAudioUnitCreate;
@property (nonatomic) double sinParam;

@end

@implementation AudioUnitSample

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isAudioUnitCreate = NO;
        self.sinParam = 0;
    }
    return self;
}

- (void)dealloc {
    if (self.isAudioUnitCreate) {
        AudioComponentInstanceDispose(self.audioUnit);
    }
}

- (BOOL)createAudioUnit {
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    AudioUnit audioUnit = { 0 };
    OSStatus status = AudioComponentInstanceNew(component, &audioUnit);
    
    if (status != noErr) {
        return NO;
    }
    
    self.isAudioUnitCreate = YES;
    self.audioUnit = audioUnit;
    
    return YES;
}

- (BOOL)setStreamFormat {
    AudioStreamBasicDescription streamFormat = {};
    streamFormat.mSampleRate = (double)SAMPLE_RATE;
    streamFormat.mFormatID = kAudioFormatLinearPCM;
    streamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    streamFormat.mFramesPerPacket = 1;
    streamFormat.mChannelsPerFrame = 1;
    streamFormat.mBitsPerChannel = sizeof(int16_t) * 8;
    streamFormat.mBytesPerFrame = streamFormat.mChannelsPerFrame * streamFormat.mBitsPerChannel / 8;
    streamFormat.mBytesPerPacket = streamFormat.mBytesPerFrame * streamFormat.mFramesPerPacket;
    OSStatus status = AudioUnitSetProperty(self.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &streamFormat,
                                  sizeof(streamFormat));
    return status == noErr;
}

- (BOOL)prepareCallback {
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = audioCallback;
    callbackStruct.inputProcRefCon = (__bridge void*)self;
    OSStatus status = AudioUnitSetProperty(self.audioUnit,
                                           kAudioUnitProperty_SetRenderCallback,
                                           kAudioUnitScope_Input,
                                           0,
                                           &callbackStruct,
                                           sizeof(callbackStruct));
    return status == noErr;
}

- (BOOL)prepare {
    BOOL success = [self createAudioUnit];
    if (!success) {
        return NO;
    }
    
    success = [self setStreamFormat];
    if (!success) {
        return NO;
    }
    
    success = [self prepareCallback];
    if (!success) {
        return NO;
    }
    
    return AudioUnitInitialize(self.audioUnit);
}

- (void)play {
    AudioOutputUnitStart(self.audioUnit);
}

@end

static OSStatus audioCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                              UInt32 inNumberFrames, AudioBufferList *ioData) {
    AudioUnitSample* audio = (__bridge  AudioUnitSample*)inRefCon;
    for (int k = 0; k < (int)ioData->mNumberBuffers; ++k) {
        AudioBuffer buffer = ioData->mBuffers[k];
        int16_t* data = (int16_t*)buffer.mData;
        for (int i = 0; i < (int)inNumberFrames; ++i) {
            data[i] = INT16_MAX * sin(audio.sinParam);
            audio.sinParam += 2 * M_PI * 440 / SAMPLE_RATE;
            if (audio.sinParam > 2 * M_PI) {
                audio.sinParam -= 2 * M_PI;
            }
        }
    }
    return noErr;
}
