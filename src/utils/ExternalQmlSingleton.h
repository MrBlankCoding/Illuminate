#pragma once

#include <QJSEngine>
#include <QQmlEngine>
#include <QtLogging>
#include <type_traits>

// handels things main owns
template <typename T>
class ExternalQmlSingleton
{
public:
    static void setQmlInstance(T *instance)
    {
        static_assert(!std::is_default_constructible_v<T>,
                      "an ExternalQmlSingleton must not be default-constructible");
        s_instance = instance;
    }

    static T *instance() { return s_instance; }
    static T *create(QQmlEngine *, QJSEngine *)
    {
        if (!s_instance)
        {
            qWarning("%s used from QML before setQmlInstance() was called",
                     T::staticMetaObject.className());
            return nullptr;
        }

        QJSEngine::setObjectOwnership(s_instance, QJSEngine::CppOwnership);
        return s_instance;
    }

private:
    inline static T *s_instance = nullptr;
};
