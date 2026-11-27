// Generates the platform icon assets from illuminate.svg outside the app build.
#include <QGuiApplication>
#include <QBuffer>
#include <QDataStream>
#include <QFile>
#include <QImage>
#include <QPainter>
#include <QSvgRenderer>

static int writeWindowsIcon(QSvgRenderer &renderer, const QString &path)
{
    static const int kSizes[] = {16, 20, 24, 32, 40, 48, 64, 128, 256};
    constexpr int kCount = sizeof(kSizes) / sizeof(kSizes[0]);
    QByteArray images[kCount];
    renderer.setViewBox(QRect(60, 60, 904, 904));

    for (int i = 0; i < kCount; ++i) {
        const int size = kSizes[i];
        QImage image(size, size, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        painter.setRenderHint(QPainter::Antialiasing, true);
        painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
        renderer.render(&painter, QRectF(0, 0, size, size));
        painter.end();

        QBuffer buffer(&images[i]);
        if (!buffer.open(QIODevice::WriteOnly) || !image.save(&buffer, "PNG")) {
            qWarning("failed to encode %dpx Windows icon", size);
            return 1;
        }
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning("failed to write Windows icon: %s", qPrintable(path));
        return 1;
    }

    QDataStream stream(&file);
    stream.setByteOrder(QDataStream::LittleEndian);
    stream << quint16(0) << quint16(1) << quint16(kCount);

    quint32 offset = 6 + kCount * 16;
    for (int i = 0; i < kCount; ++i) {
        const quint8 size = kSizes[i] == 256 ? 0 : static_cast<quint8>(kSizes[i]);
        stream << size << size << quint8(0) << quint8(0)
               << quint16(1) << quint16(32)
               << static_cast<quint32>(images[i].size()) << offset;
        offset += static_cast<quint32>(images[i].size());
    }
    for (const QByteArray &image : images)
        stream.writeRawData(image.constData(), image.size());

    if (stream.status() != QDataStream::Ok) {
        qWarning("failed to finish Windows icon: %s", qPrintable(path));
        return 1;
    }
    return 0;
}

int main(int argc, char **argv)
{
    const bool windowsIcon = argc >= 2 && QString::fromLocal8Bit(argv[1]) == QLatin1String("--windows");
    if ((windowsIcon && argc != 4) || (!windowsIcon && argc < 3)) {
        qWarning("usage: icongen <input.svg> <output.iconset-dir> | icongen --windows <input.svg> <output.ico>");
        return 2;
    }
    QGuiApplication app(argc, argv);

    const QString inputPath = QString::fromLocal8Bit(argv[windowsIcon ? 2 : 1]);
    QSvgRenderer renderer(inputPath);
    if (!renderer.isValid()) {
        qWarning("failed to load svg: %s", qPrintable(inputPath));
        return 1;
    }

    if (windowsIcon)
        return writeWindowsIcon(renderer, QString::fromLocal8Bit(argv[3]));

    // the set iconutil requires for a complete .icns
    static const struct { const char *name; int px; } kEntries[] = {
        { "icon_16x16.png", 16 },     { "icon_16x16@2x.png", 32 },
        { "icon_32x32.png", 32 },     { "icon_32x32@2x.png", 64 },
        { "icon_128x128.png", 128 },  { "icon_128x128@2x.png", 256 },
        { "icon_256x256.png", 256 },  { "icon_256x256@2x.png", 512 },
        { "icon_512x512.png", 512 },  { "icon_512x512@2x.png", 1024 },
    };

    const QString outDir = QString::fromLocal8Bit(argv[2]);
    for (const auto &entry : kEntries) {
        QImage image(entry.px, entry.px, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        painter.setRenderHint(QPainter::Antialiasing, true);
        painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
        renderer.render(&painter, QRectF(0, 0, entry.px, entry.px));
        painter.end();

        const QString path = outDir + QLatin1Char('/') + QLatin1String(entry.name);
        if (!image.save(path, "PNG")) {
            qWarning("failed to write %s", qPrintable(path));
            return 1;
        }
    }
    return 0;
}
