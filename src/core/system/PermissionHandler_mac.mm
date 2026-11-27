#include "PermissionHandler.h"

#include <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreLocation/CoreLocation.h>
#include <QCoreApplication>
#include <QMetaObject>
#include <QPointer>
#include <QThread>

namespace {
void warnIfOffMainThread(const char *what)
{
    if (QCoreApplication::instance()
        && QThread::currentThread() != QCoreApplication::instance()->thread()) {
        qWarning("PermissionHandler: %s called off the Qt main thread — "
                 "CLLocationManager traps here", what);
    }
}

CLLocationManager *locationManager()
{
    static CLLocationManager *manager = [] {
        return [[CLLocationManager alloc] init];
    }();
    return manager;
}

PermissionHandler::SystemAccess mediaAccess(AVMediaType type)
{
    switch ([AVCaptureDevice authorizationStatusForMediaType:type]) {
    case AVAuthorizationStatusAuthorized:    return PermissionHandler::Granted;
    case AVAuthorizationStatusNotDetermined: return PermissionHandler::NotDetermined;
    default:                                 return PermissionHandler::Denied;
    }
}

PermissionHandler::SystemAccess locationAccess()
{
    warnIfOffMainThread("locationAccess()");
    CLAuthorizationStatus status;
    status = locationManager().authorizationStatus;
    if (status == kCLAuthorizationStatusNotDetermined)
        return PermissionHandler::NotDetermined;
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted)
        return PermissionHandler::Denied;
    return PermissionHandler::Granted;
}

} // namespace

PermissionHandler::SystemAccess PermissionHandler::platformSystemAccess(SystemResource resource)
{
    switch (resource) {
    case Camera:        return mediaAccess(AVMediaTypeVideo);
    case Microphone:    return mediaAccess(AVMediaTypeAudio);
    case Location:      return locationAccess();
    case ScreenCapture: return CGPreflightScreenCaptureAccess() ? Granted : NotDetermined;
    }
    return Granted;
}

void PermissionHandler::platformRequestSystemAccess(SystemResource resource)
{
    QPointer<PermissionHandler> self(this);
    auto changed = [self]() {
        QMetaObject::invokeMethod(self.data(), [self]() {
            if (self)
                emit self->systemAccessChanged();
        }, Qt::QueuedConnection);
    };

    switch (resource) {
    case Camera:
    case Microphone: {
        [AVCaptureDevice requestAccessForMediaType:(resource == Camera ? AVMediaTypeVideo : AVMediaTypeAudio)
                                 completionHandler:^(BOOL) { changed(); }];
        return;
    }
    case Location:
        warnIfOffMainThread("requestWhenInUseAuthorization");
        [locationManager() requestWhenInUseAuthorization];
        return;
    case ScreenCapture:
        CGRequestScreenCaptureAccess();
        changed();
        return;
    }
}

void PermissionHandler::platformOpenSystemSettings(SystemResource resource)
{
    NSString *pane = nil;
    switch (resource) {
    case Camera:        pane = @"Privacy_Camera"; break;
    case Microphone:    pane = @"Privacy_Microphone"; break;
    case Location:      pane = @"Privacy_LocationServices"; break;
    case ScreenCapture: pane = @"Privacy_ScreenCapture"; break;
    }
    NSString *url = [@"x-apple.systempreferences:com.apple.preference.security?" stringByAppendingString:pane];
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:url]];
}

bool PermissionHandler::platformIsDefaultBrowser()
{
    NSString *ourId = NSBundle.mainBundle.bundleIdentifier;
    if (!ourId)
        return false;
    NSURL *probe = [NSURL URLWithString:@"https://example.com"];
    NSURL *handler = [NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:probe];
    if (!handler)
        return false;
    return [[NSBundle bundleWithURL:handler].bundleIdentifier isEqualToString:ourId];
}

void PermissionHandler::platformMakeDefaultBrowser()
{
    QPointer<PermissionHandler> self(this);
    auto finish = [self](bool ok, QString error) {
        QMetaObject::invokeMethod(self.data(), [self, ok, error]() {
            if (self)
                self->finishDefaultBrowserRequest(ok, error);
        }, Qt::QueuedConnection);
    };

    if (@available(macOS 12.0, *))
    {
        NSWorkspace *ws = NSWorkspace.sharedWorkspace;
        NSURL *app = NSBundle.mainBundle.bundleURL;
        [ws setDefaultApplicationAtURL:app
                toOpenURLsWithScheme:@"http"
                   completionHandler:^(NSError *httpError) {
                       if (httpError)
                       {
                           finish(false, QString::fromNSString(httpError.localizedDescription));
                           return;
                       }
                        [NSWorkspace.sharedWorkspace setDefaultApplicationAtURL:app
                               toOpenURLsWithScheme:@"https"
                                  completionHandler:^(NSError *httpsError) {
                                      finish(!httpsError,
                                             httpsError ? QString::fromNSString(httpsError.localizedDescription)
                                                        : QString());
                                  }];
                   }];
    }
    else
    {
        finish(false, QStringLiteral("Requires macOS 12 or later"));
    }
}
