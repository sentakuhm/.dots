#include "common.hpp"

#include <qstandardpaths.h>

namespace sentaku::shell::config {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcConfig, "sentaku.config", QtInfoMsg)

QString configDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + u"/sentaku"_s;
}

QString monitorConfigDir() {
    return configDir() + u"/monitors"_s;
}

} // namespace sentaku::shell::config
