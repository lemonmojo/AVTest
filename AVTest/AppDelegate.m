//
//  AppDelegate.m
//  AVTest
//
//  Created by Felix Deimel on 21.11.19.
//  Copyright © 2019 Felix Deimel. All rights reserved.
//

#import "AppDelegate.h"

@import AVKit;

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@property (copy) NSURL *audioSampleURL;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.audioSampleURL = [NSBundle.mainBundle URLForResource:@"sample" withExtension:@"wav"];
}

- (IBAction)buttonJustPlay_action:(id)sender {
    [self playSoundAtURL:self.audioSampleURL explicitlySetOutputDevice:NO explicitlyDisableInputDevice:NO];
}

- (IBAction)buttonPlayAndDisableInputDevice_action:(id)sender {
    [self playSoundAtURL:self.audioSampleURL explicitlySetOutputDevice:NO explicitlyDisableInputDevice:YES];
}

- (IBAction)buttonPlayAndSetOutputDevice_action:(id)sender {
    [self playSoundAtURL:self.audioSampleURL explicitlySetOutputDevice:YES explicitlyDisableInputDevice:NO];
}

- (BOOL)playSoundAtURL:(NSURL*)url explicitlySetOutputDevice:(BOOL)explicitlySetOutputDevice explicitlyDisableInputDevice:(BOOL)explicitlyDisableInputDevice {
    NSError *error = nil;
    
    __block AVAudioEngine *engine = AVAudioEngine.new;
    
    if (explicitlySetOutputDevice) {
        AudioDeviceID defaultOutputDevice = [self defaultOutputDevice];
        
        if (defaultOutputDevice == 0) {
            return NO;
        }
        
        if (![self setEngine:engine outputDevice:defaultOutputDevice]) {
            return NO;
        }
    } else if (explicitlyDisableInputDevice) {
        if (![self setEngine:engine inputDeviceEnabled:NO]) {
            return NO;
        }
    }
    
    AVAudioFile *file = [[AVAudioFile alloc] initForReading:url error:&error];
    
    if (!file) {
        NSLog(@"AVAudioFile error: %@", error);
        return NO;
    }

    __block AVAudioPlayerNode *player = AVAudioPlayerNode.new;
    
    [engine attachNode:player];
    [engine connect:player to:engine.mainMixerNode format:nil];
    
    // Micro Snitch starts reporting input after this line
    if (![engine startAndReturnError:&error]) {
        NSLog(@"AVAudioEngine failed to start: %@", error);
        return NO;
    }
    
    [player scheduleFile:file atTime:[AVAudioTime timeWithHostTime:mach_absolute_time()] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
            
            [engine stop];
            [engine detachNode:player];
            
            player = nil;
            engine = nil;
            
            NSLog(@"Player finished");
        });
    }];
    
    [player play];
    
    return YES;
}

- (AudioDeviceID)defaultOutputDevice {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultSystemOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster };
    
    AudioDeviceID outputDeviceID;
    UInt32 propertySize = sizeof(outputDeviceID);
    
    OSStatus err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &propertySize, &outputDeviceID);
    
    if (err) {
        NSLog(@"AudioObjectGetPropertyData failed: %d", (int)err);
        
        return 0;
    }
    
    return outputDeviceID;
}

- (BOOL)setEngine:(AVAudioEngine*)engine outputDevice:(AudioDeviceID)outputDeviceID {
    const AudioUnitElement outputBus = 0;
    AudioUnit outputUnit = engine.outputNode.audioUnit;
    
    OSStatus err = AudioUnitSetProperty(outputUnit,
                                        kAudioOutputUnitProperty_CurrentDevice,
                                        kAudioUnitScope_Global,
                                        outputBus,
                                        &outputDeviceID,
                                        sizeof(outputDeviceID));
    
    if (err) {
        NSLog(@"AudioUnitSetProperty failed: %d", (int)err);
        
        return NO;
    }
    
    return YES;
}

- (BOOL)setEngine:(AVAudioEngine*)engine inputDeviceEnabled:(BOOL)enableInputDevice {
    // See https://developer.apple.com/documentation/audiotoolbox/1534116-i_o_audio_unit_properties/kaudiooutputunitproperty_enableio
    
    const AudioUnitElement inputBus = 1;
    AudioUnit inputUnit = engine.inputNode.audioUnit;
    
    UInt32 enableInputDeviceVal = enableInputDevice ? 1 : 0;
    
    OSStatus err = AudioUnitSetProperty(inputUnit,
                                        kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Input,
                                        inputBus,
                                        &enableInputDeviceVal,
                                        sizeof(enableInputDeviceVal));
    
    if (err) {
        NSLog(@"AudioUnitSetProperty failed: %d", (int)err);
        
        return NO;
    }
    
    return YES;
}

@end
