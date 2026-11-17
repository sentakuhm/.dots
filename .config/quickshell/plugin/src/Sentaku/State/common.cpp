#include "common.hpp"

#include <qstandardpaths.h>

namespace sentaku::shell::state {

using Qt::StringLiterals::operator""_s;

Q_LOGGING_CATEGORY(lcState, "sentaku.state", QtInfoMsg)

QString stateDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + u"/sentaku"_s;
}

QString monitorStateDir() {
    return stateDir() + u"/monitors"_s;
}

QString runtimeDir() {
    return QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + u"/sentaku"_s;
}

QString monitorRuntimeDir() {
    return runtimeDir() + u"/monitors"_s;
}

} // namespace sentaku::shell::state
