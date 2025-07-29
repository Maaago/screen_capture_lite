#include "CGFrameProcessor.h"
#include "ScreenCapture.h"
#include "TargetConditionals.h"
#include <ApplicationServices/ApplicationServices.h>
#include <ScreenCaptureKit/ScreenCaptureKit.h>
#include <algorithm>
#include <iostream>
#include <vector>

// Base on https://github.com/ro31337/screenshot_macos/blob/main/main_screencapturekit.go

namespace SL {
namespace Screen_Capture {

    DUPL_RETURN CGFrameProcessor::Init(std::shared_ptr<Thread_Data> data, Window &window)
    {
        auto ret = DUPL_RETURN::DUPL_RETURN_SUCCESS;
        Data = data;
        return ret;
    }
    DUPL_RETURN CGFrameProcessor::ProcessFrame(const Window &window)
    {
        auto Ret = DUPL_RETURN_SUCCESS;

        // static CGImageRef capture(CGDirectDisplayID id, CGRect diIntersectDisplayLocal, CGColorSpaceRef colorSpace) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block CGImageRef imageRef = nil;
        [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent* content, NSError* error) {
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

            @autoreleasepool {
                if (error) {
                    dispatch_semaphore_signal(semaphore);
                    return;
                }

                SCDisplay* target = nil;
                for (SCDisplay *display in content.displays) {
                    if (display.displayID == SelectedMonitor.Id) {
                        target = display;
                        break;
                    }
                }
                if (!target) {
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                SCContentFilter* filter = [[SCContentFilter alloc] initWithDisplay:target excludingWindows:@[]];
                SCStreamConfiguration* config = [[SCStreamConfiguration alloc] init];
                config.sourceRect = CGRectMake(window.Position.x, window.Position.y, window.Size.x, window.Size.y);
                config.width = window.Size.x;
                config.height = window.Size.y;

                [SCScreenshotManager captureImageWithFilter:filter
                                            configuration:config
                                        completionHandler:^(CGImageRef img, NSError* error) {
                    if (!error) {
                        imageRef = CGImageCreateCopyWithColorSpace(img, colorSpace);
                    }
                    dispatch_semaphore_signal(semaphore);

	                CGColorSpaceRelease(colorSpace);
                }];
            }
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        if (!imageRef)
            return DUPL_RETURN_ERROR_EXPECTED; // this happens when the monitors change.

        auto width = CGImageGetWidth(imageRef);
        auto height = CGImageGetHeight(imageRef);

        if (width != window.Size.x || height != window.Size.y) {
            CGImageRelease(imageRef);
            return DUPL_RETURN_ERROR_EXPECTED; // this happens when the window sizes change.
        }
        auto prov = CGImageGetDataProvider(imageRef);
        if (!prov) {
            CGImageRelease(imageRef);
            return DUPL_RETURN_ERROR_EXPECTED;
        }
        auto bytesperrow = CGImageGetBytesPerRow(imageRef);
        auto bitsperpixel = CGImageGetBitsPerPixel(imageRef);
        // right now only support full 32 bit images.. Most desktops should run this as its the most efficent
        assert(bitsperpixel == sizeof(ImageBGRA) * 8);

        auto rawdatas = CGDataProviderCopyData(prov);
        auto buf = CFDataGetBytePtr(rawdatas);
        ProcessCapture(Data->WindowCaptureData, *this, window, buf, bytesperrow);

        CFRelease(rawdatas);
        CGImageRelease(imageRef);
        return Ret;
    }
} // namespace Screen_Capture
} // namespace SL
