#pragma once

#include <QObject>

#include <functional>

// A page asking "Leave site? Changes you made may not be saved." before it
// closes, reloads or navigates away. The app shows its own dialog rather than
// Chromium's so it learns the answer: closing the window or quitting needs to
// know when the person chose to stay.
//
// Lives on the Qt thread; unanswered requests count as "stay".
class BeforeUnloadRequest : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isReload READ isReload CONSTANT)
    Q_PROPERTY(bool answered READ answered NOTIFY finished)

public:
    BeforeUnloadRequest(bool isReload, std::function<void(bool leave)> respond, QObject *parent = nullptr);
    ~BeforeUnloadRequest() override;

    bool isReload() const { return m_isReload; }
    bool answered() const { return !m_respond; }

    Q_INVOKABLE void leave() { answer(true); }
    Q_INVOKABLE void stay() { answer(false); }
    // the page went away while asking (CEF reset its dialogs): nothing to answer
    void dismiss();

signals:
    void answeredWith(bool leave);
    // answered or dismissed; the dialog should close
    void finished();

private:
    void answer(bool leave);

    bool m_isReload;
    std::function<void(bool)> m_respond;
};
