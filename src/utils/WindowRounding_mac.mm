#include "WindowRounding.h"

#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <QQuickWindow>

static const void *kIlluminateTitlebarObserverKey = &kIlluminateTitlebarObserverKey;

static void configureMacTitlebar(NSWindow *window, CGFloat barHeight) {
  if (!window)
    return;
  window.styleMask |= NSWindowStyleMaskFullSizeContentView;
  window.titlebarAppearsTransparent = YES;
  window.titleVisibility = NSWindowTitleHidden;

  NSArray<NSButton *> *buttons = @[
    [window standardWindowButton:NSWindowCloseButton],
    [window standardWindowButton:NSWindowMiniaturizeButton],
    [window standardWindowButton:NSWindowZoomButton],
  ];
  NSView *titlebarView = buttons.firstObject.superview;
  NSView *titlebarContainer = titlebarView ? titlebarView.superview : nil;
  if (titlebarContainer) {
    NSRect frame = titlebarContainer.frame;
    frame.size.height = barHeight;
    frame.origin.y = window.frame.size.height - barHeight;
    titlebarContainer.frame = frame;
  }
  if (titlebarView) {
    NSRect frame = titlebarView.frame;
    frame.size.height = barHeight;
    titlebarView.frame = frame;
  }
  for (NSButton *button in buttons) {
    if (!button)
      continue;
    NSRect frame = button.frame;
    const CGFloat centerY = (barHeight - frame.size.height) / 2.0;
    frame.origin.y = centerY + (titlebarView.isFlipped ? 3.0 : -3.0);
    button.frame = frame;
  }
}

@interface IlluminateTitlebarObserver : NSObject {
  NSRect _savedFrame;
  BOOL _savedWindowWasZoomed;
  BOOL _hasSavedFrame;
}
@property(nonatomic, assign) CGFloat barHeight;
- (void)windowWillEnterFullscreen:(NSNotification *)notification;
- (void)windowWillExitFullscreen:(NSNotification *)notification;
- (void)windowDidExitFullscreen:(NSNotification *)notification;
@end

@implementation IlluminateTitlebarObserver
- (void)windowWillEnterFullscreen:(NSNotification *)notification {
  NSWindow *window = notification.object;
  if (!window)
    return;
  _savedFrame = window.frame;
  _savedWindowWasZoomed = window.isZoomed;
  _hasSavedFrame = YES;
}
- (void)windowWillExitFullscreen:(NSNotification *)notification {
  configureMacTitlebar(notification.object, self.barHeight);
}
- (void)windowDidExitFullscreen:(NSNotification *)notification {
  NSWindow *window = notification.object;
  if (!window)
    return;
  configureMacTitlebar(window, self.barHeight);
  if (_hasSavedFrame && !_savedWindowWasZoomed)
    [window setFrame:_savedFrame display:YES animate:NO];
  configureMacTitlebar(window, self.barHeight);
  _hasSavedFrame = NO;
}
- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [super dealloc];
}
@end

namespace WindowRounding {

void applyMacTitleBarStyle(QQuickWindow *window, qreal barHeight) {
  if (!window)
    return;

  NSView *view = reinterpret_cast<NSView *>(window->winId());
  NSWindow *nsWindow = view ? view.window : nil;
  if (!nsWindow)
    return;

  nsWindow.styleMask |= NSWindowStyleMaskFullSizeContentView;
  nsWindow.titlebarAppearsTransparent = YES;
  nsWindow.titleVisibility = NSWindowTitleHidden;
  if (!objc_getAssociatedObject(nsWindow, kIlluminateTitlebarObserverKey)) {
    IlluminateTitlebarObserver *observer = [[IlluminateTitlebarObserver alloc] init];
    observer.barHeight = barHeight;
    [NSNotificationCenter.defaultCenter addObserver:observer
                                           selector:@selector(windowWillEnterFullscreen:)
                                               name:NSWindowWillEnterFullScreenNotification
                                             object:nsWindow];
    [NSNotificationCenter.defaultCenter addObserver:observer
                                           selector:@selector(windowWillExitFullscreen:)
                                               name:NSWindowWillExitFullScreenNotification
                                             object:nsWindow];
    [NSNotificationCenter.defaultCenter addObserver:observer
                                           selector:@selector(windowDidExitFullscreen:)
                                               name:NSWindowDidExitFullScreenNotification
                                             object:nsWindow];
    objc_setAssociatedObject(nsWindow, kIlluminateTitlebarObserverKey, observer,
                             OBJC_ASSOCIATION_RETAIN);
    [observer release];
  }
  // we control window dragging
  nsWindow.movableByWindowBackground = NO;
  configureMacTitlebar(nsWindow, barHeight);
}

void setMacWindowButtonsVisible(QQuickWindow *window, bool visible) {
  if (!window)
    return;
  NSView *view = reinterpret_cast<NSView *>(window->winId());
  NSWindow *nsWindow = view ? view.window : nil;
  if (!nsWindow)
    return;
  for (NSWindowButton kind : {NSWindowCloseButton, NSWindowMiniaturizeButton,
                              NSWindowZoomButton})
    [nsWindow standardWindowButton:kind].hidden = !visible;
}


void performMacHaptic(int pattern) {
  const NSHapticFeedbackPattern kind = pattern == 1 ? NSHapticFeedbackPatternAlignment
                                     : pattern == 2 ? NSHapticFeedbackPatternLevelChange
                                                    : NSHapticFeedbackPatternGeneric;
  [[NSHapticFeedbackManager defaultPerformer] performFeedbackPattern:kind
                                                     performanceTime:NSHapticFeedbackPerformanceTimeNow];
}

} // namespace WindowRounding
