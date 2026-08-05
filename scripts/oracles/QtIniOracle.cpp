// Consema's repository-owned Qt 6 QSettings::IniFormat differential adapter.
#include <QByteArray>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QFile>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QSysInfo>
#include <QVariant>

#include <algorithm>
#include <cstdio>
#include <utility>
#include <vector>

namespace {

void emitLine(const QByteArray &line)
{
    std::fwrite(line.constData(), 1, static_cast<std::size_t>(line.size()), stdout);
    std::fputc('\n', stdout);
}

QByteArray transport(const QString &value)
{
    return value.toUtf8().toHex();
}

void runtimeFacts()
{
    emitLine("qt.version\t" + QByteArray(qVersion()));
    emitLine("qt.build-abi\t" + QSysInfo::buildAbi().toUtf8());
    emitLine("qt.cpu\t" + QSysInfo::currentCpuArchitecture().toUtf8());
    emitLine("os.product-type\t" + QSysInfo::productType().toUtf8());
    emitLine("os.product-version\t" + QSysInfo::productVersion().toUtf8());
    emitLine("os.kernel-type\t" + QSysInfo::kernelType().toUtf8());
    emitLine("os.kernel-version\t" + QSysInfo::kernelVersion().toUtf8());
}

int runCase(const QString &path)
{
    QFile input(path);
    if (!input.open(QIODevice::ReadOnly)) {
        emitLine("failed\tQSettings::AccessError");
        return 0;
    }
    const QByteArray source = input.readAll();
    input.close();
    emitLine("input-sha256\t" + QCryptographicHash::hash(source, QCryptographicHash::Sha256).toHex());

    QSettings settings(path, QSettings::IniFormat);
    settings.setFallbacksEnabled(false);
    settings.sync();
    QStringList keys = settings.allKeys();
    std::sort(keys.begin(), keys.end(), [](const QString &left, const QString &right) {
        return QString::compare(left, right, Qt::CaseSensitive) < 0;
    });
    std::vector<std::pair<QString, QString>> entries;
    entries.reserve(static_cast<std::size_t>(keys.size()));
    for (const QString &key : std::as_const(keys)) {
        entries.emplace_back(key, settings.value(key).toString());
    }

    switch (settings.status()) {
    case QSettings::NoError:
        emitLine("complete");
        for (const auto &[key, value] : entries) {
            emitLine("entry\t" + transport(key) + '\t' + transport(value));
        }
        return 0;
    case QSettings::AccessError:
        emitLine("failed\tQSettings::AccessError");
        return 0;
    case QSettings::FormatError:
        emitLine("failed\tQSettings::FormatError");
        return 0;
    }
    emitLine("failed\tQSettings::UnknownStatus");
    return 0;
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    const QStringList arguments = application.arguments();
    if (arguments.size() == 2 && arguments.at(1) == QStringLiteral("--runtime")) {
        runtimeFacts();
        return 0;
    }
    if (arguments.size() != 2) {
        emitLine("usage: QtIniOracle <input> | --runtime");
        return 2;
    }
    return runCase(arguments.at(1));
}
