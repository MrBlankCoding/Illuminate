#include "BeforeUnloadRequest.h"

#include <utility>

BeforeUnloadRequest::BeforeUnloadRequest(bool isReload, std::function<void(bool)> respond, QObject *parent)
    : QObject(parent), m_isReload(isReload), m_respond(std::move(respond))
{
}

BeforeUnloadRequest::~BeforeUnloadRequest()
{
    // dropped without an answer: the page stays, as with Escape
    if (auto respond = std::exchange(m_respond, nullptr))
        respond(false);
}

void BeforeUnloadRequest::answer(bool leave)
{
    auto respond = std::exchange(m_respond, nullptr);
    if (!respond)
        return;
    respond(leave);
    emit answeredWith(leave);
    emit finished();
}

void BeforeUnloadRequest::dismiss()
{
    if (!std::exchange(m_respond, nullptr))
        return;
    emit finished();
}
