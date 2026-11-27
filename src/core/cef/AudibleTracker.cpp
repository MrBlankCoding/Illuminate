#include "AudibleTracker.h"

AudibleTracker::AudibleTracker(QObject *parent)
    : QObject(parent)
{
    m_hold.setSingleShot(true);
    m_hold.setInterval(kSilenceHoldMs);
    connect(&m_hold, &QTimer::timeout, this, [this]() {
        if (m_frames.isEmpty())
            setAudible(false);
    });
}

void AudibleTracker::report(const QString &frameId, bool audible)
{
    if (audible)
        m_frames.insert(frameId);
    else
        m_frames.remove(frameId);

    if (!m_frames.isEmpty())
    {
        m_hold.stop();
        setAudible(true);
    }
    else if (m_audible && !m_hold.isActive())
    {
        m_hold.start();
    }
}

void AudibleTracker::clear()
{
    m_frames.clear();
    m_hold.stop();
    setAudible(false);
}

void AudibleTracker::adopt(const AudibleTracker &other)
{
    m_frames = other.m_frames;
    m_hold.stop();
    setAudible(other.m_audible || !m_frames.isEmpty());
    if (m_frames.isEmpty() && m_audible)
        m_hold.start();
}

void AudibleTracker::setAudible(bool audible)
{
    if (m_audible == audible)
        return;
    m_audible = audible;
    emit audibleChanged(audible);
}
