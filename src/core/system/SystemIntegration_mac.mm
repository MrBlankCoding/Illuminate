#include "SystemIntegration.h"

#include <QMetaObject>

#import <AppKit/AppKit.h>

SystemIntegration::SystemIntegration(QObject *parent)
    : QObject(parent)
{
    refreshReduceMotion();
    id observer = [NSWorkspace.sharedWorkspace.notificationCenter
        addObserverForName:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *) {
                    refreshReduceMotion();
                }];
    m_observer = (__bridge_retained void *)observer;
}

SystemIntegration::~SystemIntegration()
{
    if (m_observer)
    {
        id observer = (__bridge_transfer id)m_observer;
        [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:observer];
        m_observer = nullptr;
    }
    if (m_activity)
    {
        NSUserActivity *activity = (__bridge_transfer NSUserActivity *)m_activity;
        [activity invalidate];
        m_activity = nullptr;
    }
    if (!m_badge.isEmpty())
        NSApp.dockTile.badgeLabel = nil;
}

void SystemIntegration::refreshReduceMotion()
{
    const bool reduce = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
    if (reduce == m_reduceMotion)
        return;
    m_reduceMotion = reduce;
    emit reduceMotionChanged();
}

void SystemIntegration::setCurrentPage(const QUrl &url, const QString &title)
{
    const QUrl page = handoffUrl(url);
    if (page == m_currentPage && title == m_currentTitle)
        return;
    m_currentPage = page;
    m_currentTitle = title;

    if (page.isEmpty())
    {
        if (m_activity)
        {
            NSUserActivity *activity = (__bridge_transfer NSUserActivity *)m_activity;
            m_activity = nullptr;
            [activity invalidate];
        }
        return;
    }

    if (!m_activity)
    {
        NSUserActivity *activity = [[NSUserActivity alloc]
            initWithActivityType:NSUserActivityTypeBrowsingWeb];
        activity.eligibleForHandoff = YES;
        m_activity = (__bridge_retained void *)activity;
    }
    NSUserActivity *activity = (__bridge NSUserActivity *)m_activity;
    activity.webpageURL = page.toNSURL();
    activity.title = title.isEmpty() ? nil : title.toNSString();
    [activity becomeCurrent];
}

void SystemIntegration::setActiveDownloads(int count)
{
    const QString badge = dockBadge(count);
    if (badge == m_badge)
        return;
    m_badge = badge;
    NSApp.dockTile.badgeLabel = badge.isEmpty() ? nil : badge.toNSString();
}
