#include "ScreenCapture.h"
#include "internal/SCCommon.h"
#include <ApplicationServices/ApplicationServices.h>
#include <Foundation/Foundation.h>
#include <ScreenCaptureKit/ScreenCaptureKit.h>
#include <AppKit/AppKit.h>

// Base on https://github.com/ro31337/screenshot_macos/blob/main/main_screencapturekit.go

static void initializeIfNeeded()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [NSApplication sharedApplication];
    });
}

namespace SL{
    namespace Screen_Capture{
        std::vector<Monitor> GetMonitors()
        {
            __block std::vector<Monitor> monitors;

            @autoreleasepool
            {
                initializeIfNeeded();

                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent * _Nullable shareableContent, NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"Error getting shareable content: %@", error.localizedDescription);
                    } else {
                        for(SCDisplay* display in shareableContent.displays)
                        {
                            auto name = std::string("Monitor ") + std::to_string(display.displayID);

                            monitors.push_back(CreateMonitor(
                                static_cast<int>(monitors.size()),
                                static_cast<int>(display.displayID),
                                display.height,
                                display.width,
                                display.frame.origin.x,
                                display.frame.origin.y,
                                name,
                                1.0f
                            ));
                        }
                    }
                    dispatch_semaphore_signal(semaphore);
                }];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            }

            return monitors;
        }
        /*
        std::vector<Monitor> GetMonitors()
        {
            std::vector<Monitor> ret;
            std::vector<CGDirectDisplayID> displays;
            CGDisplayCount count=0;
            //get count
            CGGetActiveDisplayList(0, 0, &count);
            displays.resize(count);
    
            CGGetActiveDisplayList(count, displays.data(), &count);
            for(auto  i = 0; i < count; i++) {
                //only include non-mirrored displays
                if(CGDisplayMirrorsDisplay(displays[i]) == kCGNullDirectDisplay){
                    
                    auto dismode =CGDisplayCopyDisplayMode(displays[i]);
                    
                    auto width = CGDisplayModeGetPixelWidth(dismode);
                    auto height = CGDisplayModeGetPixelHeight(dismode);
                    CGDisplayModeRelease(dismode);
                    auto r = CGDisplayBounds(displays[i]);
                    auto scale = static_cast<float>(width)/static_cast<float>(r.size.width);
                    auto name = std::string("Monitor ") + std::to_string(displays[i]);
                    ret.push_back(CreateMonitor(static_cast<int>(ret.size()), displays[i],height,width, int(r.origin.x), int(r.origin.y), name, scale));
                }
            }
            return ret;
        }
        */
    }
}
