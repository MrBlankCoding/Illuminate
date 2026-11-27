#include <QColor>
#include <QRect>

#include <unordered_map>
#include <unordered_set>

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static BOOL cefAcceptsFirstResponder(id self, SEL _cmd)
{
    return YES;
}

static void installAcceptsFirstResponderHook(void *view)
{
    NSView *nsView = (__bridge NSView *)view;
    if (!nsView)
        return;

    Class cls = [nsView class];
    if (class_getInstanceMethod(cls, @selector(acceptsFirstResponder)))
    {
        class_replaceMethod(cls, @selector(acceptsFirstResponder),
                            (IMP)cefAcceptsFirstResponder, "B@:");
    }
}

// |view| is the NSView CEF created as a child of the Qt window's content view.
void cefSetNativeViewGeometry(void *view, const QRect &rect, bool visible)
{
    NSView *nsView = (__bridge NSView *)view;
    if (!nsView)
        return;

    [nsView setHidden:!visible];
    if (!visible)
        return;

    // frames are driven from Qt, so stop AppKit from also resizing the view
    nsView.autoresizingMask = NSViewNotSizable;

    NSRect frame = NSMakeRect(rect.x(), rect.y(), rect.width(), rect.height());
    NSView *parent = nsView.superview;
    if (parent && !parent.isFlipped)
        frame.origin.y = NSHeight(parent.bounds) - rect.y() - rect.height();
    if (!NSEqualRects(nsView.frame, frame))
        [nsView setFrame:frame];

    installAcceptsFirstResponderHook(view);
}

void cefSetNativeViewCornerRadius(void *view, qreal radius)
{
    NSView *nsView = (__bridge NSView *)view;
    if (!nsView)
        return;

    nsView.wantsLayer = YES;
    CALayer *layer = nsView.layer;
    if (!layer)
        return;
    layer.cornerRadius = radius;
    layer.cornerCurve = kCACornerCurveContinuous;
    layer.masksToBounds = radius > 0;
}

bool cefResignNativeFocus(void *view)
{
    NSView *nsView = (__bridge NSView *)view;
    NSWindow *window = nsView.window;
    if (!window)
        return false;

    NSResponder *responder = window.firstResponder;
    if (![responder isKindOfClass:[NSView class]] || ![(NSView *)responder isDescendantOf:nsView])
        return false;

    [window makeFirstResponder:nsView.superview];
    return true;
}

static NSWindow *cefWindowFromHandle(void *handle)
{
    id object = (__bridge id)handle;
    if ([object isKindOfClass:[NSWindow class]])
        return (NSWindow *)object;
    if ([object isKindOfClass:[NSView class]])
        return ((NSView *)object).window;
    return nil;
}

static BOOL cefCannotBecomeMain(id, SEL)
{
    return NO;
}

static char kRefuseKeyTag;
static std::unordered_map<void *, IMP> originalCanBecomeKey;

static BOOL cefCanBecomeKey(id self, SEL cmd)
{
    if (objc_getAssociatedObject(self, &kRefuseKeyTag))
        return NO;
    for (Class cls = object_getClass(self); cls; cls = class_getSuperclass(cls))
    {
        const auto it = originalCanBecomeKey.find((__bridge void *)cls);
        if (it != originalCanBecomeKey.end())
            return ((BOOL (*)(id, SEL))it->second)(self, cmd);
    }
    return YES;
}

static void keepParentMain(NSWindow *child)
{
    Class cls = object_getClass(child);
    while (cls && [NSStringFromClass(cls) hasPrefix:@"NSKVONotifying_"])
        cls = class_getSuperclass(cls);

    static std::unordered_set<void *> patched;
    if (!cls || !patched.insert((__bridge void *)cls).second)
        return;
    class_replaceMethod(cls, @selector(canBecomeMainWindow), (IMP)cefCannotBecomeMain, "B@:");
    originalCanBecomeKey[(__bridge void *)cls] = class_getMethodImplementation(cls, @selector(canBecomeKeyWindow));
    class_replaceMethod(cls, @selector(canBecomeKeyWindow), (IMP)cefCanBecomeKey, "B@:");
}

// true while one of the page windows hung off |parentView|'s window has key
bool cefChildWindowIsKey(void *parentView)
{
    NSWindow *parent = ((__bridge NSView *)parentView).window;
    NSWindow *key = NSApp.keyWindow;
    return parent && key && key.parentWindow == parent;
}

void cefSetChildWindowCanTakeKey(void *childHandle, bool allowed)
{
    NSWindow *child = cefWindowFromHandle(childHandle);
    if (child)
        objc_setAssociatedObject(child, &kRefuseKeyTag, allowed ? nil : @YES, OBJC_ASSOCIATION_RETAIN);
}

// |parentView| is our Qt window's NSView, |childHandle| the CEF window's handle
void cefAttachChildWindow(void *parentView, void *childHandle)
{
    NSWindow *parent = ((__bridge NSView *)parentView).window;
    NSWindow *child = cefWindowFromHandle(childHandle);
    if (!parent || !child || child.parentWindow == parent)
        return;

    [child.parentWindow removeChildWindow:child];
    keepParentMain(child);
    child.hasShadow = NO;
    child.opaque = NO;
    child.backgroundColor = NSColor.clearColor;
    // not a window of its own to Mission Control or Cmd-`
    child.collectionBehavior |= NSWindowCollectionBehaviorTransient
        | NSWindowCollectionBehaviorIgnoresCycle
        | NSWindowCollectionBehaviorFullScreenAuxiliary;
    [parent addChildWindow:child ordered:NSWindowAbove];
}

void cefSetChildWindowGeometry(void *parentViewHandle, void *childHandle, const QRect &rect, bool visible)
{
    NSView *parentView = (__bridge NSView *)parentViewHandle;
    NSWindow *child = cefWindowFromHandle(childHandle);
    NSWindow *expectedParent = parentView.window;
    if (child && expectedParent && child.parentWindow != expectedParent)
    {
        cefAttachChildWindow(parentViewHandle, childHandle);
    }

    if (!parentView || !child || !child.parentWindow || rect.isEmpty() || !visible)
    {
        if (child)
        {
            child.alphaValue = 0.0;
            [child orderOut:nil];
        }
        return;
    }

    NSRect bounds = NSMakeRect(rect.x(), rect.y(), rect.width(), rect.height());
    const NSRect parentBounds = parentView.bounds;
    bounds = NSIntersectionRect(bounds, parentBounds);
    if (NSIsEmptyRect(bounds))
    {
        child.alphaValue = 0.0;
        [child orderOut:nil];
        return;
    }

    if (!parentView.isFlipped)
        bounds.origin.y = NSMaxY(parentBounds) - NSMaxY(bounds);

    NSWindow *parentWindow = child.parentWindow;
    const NSRect windowFrame = [parentView convertRect:bounds toView:nil];
    const NSRect screenFrame = [parentWindow convertRectToScreen:windowFrame];
    child.alphaValue = 1.0;
    if (!NSEqualRects(child.frame, screenFrame))
        [child setFrame:screenFrame display:YES];
}

void cefSetChildWindowBackgroundColor(void *childHandle, const QColor &color)
{
    NSWindow *child = cefWindowFromHandle(childHandle);
    NSView *contentView = child.contentView;
    if (!contentView || !color.isValid())
        return;

    NSColor *background = [NSColor colorWithSRGBRed:color.redF()
                                              green:color.greenF()
                                               blue:color.blueF()
                                              alpha:1.0];
    child.backgroundColor = NSColor.clearColor;
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = background.CGColor;
}

void cefRaiseChildWindow(void *parentView, void *childHandle)
{
    NSWindow *parent = ((__bridge NSView *)parentView).window;
    NSWindow *child = cefWindowFromHandle(childHandle);
    if (!parent || !child || child.parentWindow != parent)
        return;

    [child orderFront:nil];
}

void cefDetachChildWindow(void *childHandle)
{
    NSWindow *child = cefWindowFromHandle(childHandle);
    if (!child)
        return;
    child.alphaValue = 0.0;
    [child orderOut:nil];
    if (child.parentWindow)
        [child.parentWindow removeChildWindow:child];
}

void cefSetChildWindowCornerRadius(void *childHandle, qreal radius)
{
    NSView *content = cefWindowFromHandle(childHandle).contentView;
    if (!content)
        return;
    content.wantsLayer = YES;
    content.layer.cornerRadius = radius;
    content.layer.cornerCurve = kCACornerCurveContinuous;
    content.layer.masksToBounds = radius > 0;
}

// hands keyboard focus back to our window while an overlay is up
void cefFocusParentWindow(void *parentView)
{
    [((__bridge NSView *)parentView).window makeKeyWindow];
}

void cefMakeChildWindowKey(void *childHandle)
{
    NSWindow *child = cefWindowFromHandle(childHandle);
    if (!child || !child.visible)
        return;
    objc_setAssociatedObject(child, &kRefuseKeyTag, nil, OBJC_ASSOCIATION_RETAIN);
    [child makeKeyWindow];
}

bool cefMouseButtonDown()
{
    return NSEvent.pressedMouseButtons != 0;
}

bool cefChildWindowHasKey(void *childHandle)
{
    NSWindow *child = cefWindowFromHandle(childHandle);
    return child && NSApp.keyWindow == child;
}

void *cefObserveKeyLoss(void *childHandle, std::function<void()> callback)
{
    NSWindow *child = cefWindowFromHandle(childHandle);
    if (!child || !callback)
        return nullptr;
    // this file is not ARC: the token is retained here, released when stopped
    id token = [[NSNotificationCenter.defaultCenter
        addObserverForName:NSWindowDidResignKeyNotification
                    object:child
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *) { callback(); }] retain];
    return (__bridge void *)token;
}

void cefStopObservingKeyLoss(void *token)
{
    if (!token)
        return;
    id observer = (__bridge id)token;
    [NSNotificationCenter.defaultCenter removeObserver:observer];
    [observer release];
}
