// CEF on macOS requires NSApp to implement CefAppProtocol (Chromium CHECKs
// -isHandlingSendEvent while pumping events). Qt owns the NSApplication
// subclass, so the protocol is grafted onto it at runtime instead.

#include "CefManager.h"

#import <Cocoa/Cocoa.h>
#include <objc/runtime.h>

#include <include/cef_application_mac.h>

static char kHandlingSendEventKey;
static IMP s_originalSendEvent = nullptr;

static BOOL cefIsHandlingSendEvent(id self, SEL)
{
    return [objc_getAssociatedObject(self, &kHandlingSendEventKey) boolValue];
}

static void cefSetHandlingSendEvent(id self, SEL, BOOL handling)
{
    objc_setAssociatedObject(self, &kHandlingSendEventKey, @(handling),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void cefSendEvent(id self, SEL cmd, NSEvent *event)
{
    CefScopedSendingEvent sendingEventScoper;
    reinterpret_cast<void (*)(id, SEL, NSEvent *)>(s_originalSendEvent)(self, cmd, event);
}

// a window Chrome made for itself; |view| is its browser's NSView
void cefHideNativeWindow(void *view)
{
    NSWindow *window = ((__bridge NSView *)view).window;
    if (!window)
        return;
    window.alphaValue = 0;
    [window orderOut:nil];
}

void installCefAppProtocol()
{
    if (s_originalSendEvent)
        return;

    Class cls = [[NSApplication sharedApplication] class];

    const char *boolGetter = [[NSString stringWithFormat:@"%s@:", @encode(BOOL)] UTF8String];
    const char *boolSetter = [[NSString stringWithFormat:@"v@:%s", @encode(BOOL)] UTF8String];
    class_addMethod(cls, @selector(isHandlingSendEvent), reinterpret_cast<IMP>(cefIsHandlingSendEvent), boolGetter);
    class_addMethod(cls, @selector(setHandlingSendEvent:), reinterpret_cast<IMP>(cefSetHandlingSendEvent), boolSetter);

    // wrap sendEvent: without touching NSApplication's own implementation when
    // the subclass merely inherits it
    Method sendEvent = class_getInstanceMethod(cls, @selector(sendEvent:));
    s_originalSendEvent = method_getImplementation(sendEvent);
    if (!class_addMethod(cls, @selector(sendEvent:), reinterpret_cast<IMP>(cefSendEvent),
                         method_getTypeEncoding(sendEvent)))
        method_setImplementation(sendEvent, reinterpret_cast<IMP>(cefSendEvent));

    class_addProtocol(cls, @protocol(CrAppProtocol));
    class_addProtocol(cls, @protocol(CrAppControlProtocol));
    class_addProtocol(cls, @protocol(CefAppProtocol));
}
