#pragma once

#include <QString>

// What a Chrome command (shortcut or menu) does in a Chrome style page that
// lives inside our own window instead of Chrome's.
struct ChromeCommandRoute
{
    enum Kind
    {
        Chrome,
        Action,
        Blocked,
    };

    Kind kind = Chrome;
    QString action;
    QString payload;
};

ChromeCommandRoute routeChromeCommand(int commandId);
