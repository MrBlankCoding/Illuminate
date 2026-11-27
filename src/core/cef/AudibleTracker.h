#pragma once

#include <QObject>
#include <QSet>
#include <QString>
#include <QTimer>

// Whether a page is making sound, from its frames' reports, steadied for the
// speaker on its tab: sound shows at once, silence only once it has lasted.
// Players go briefly quiet all the time (buffering, the next track, an ad
// swapping in); without the hold the speaker would blink in and out.
class AudibleTracker : public QObject
{
    Q_OBJECT

public:
    static constexpr int kSilenceHoldMs = 2500;

    explicit AudibleTracker(QObject *parent = nullptr);

    bool audible() const { return m_audible; }
    void setHoldMs(int ms) { m_hold.setInterval(ms); }

    // one frame's media watcher reporting
    void report(const QString &frameId, bool audible);
    // the page is gone (closed, crashed): silent now, no hold
    void clear();
    // the page moved here from |other|'s wrapper, with whatever it was playing
    void adopt(const AudibleTracker &other);

signals:
    void audibleChanged(bool audible);

private:
    void setAudible(bool audible);

    QSet<QString> m_frames;
    QTimer m_hold;
    bool m_audible = false;
};
