#pragma once

#include <qpointer.h>
#include <qqmlintegration.h>

#include "service.hpp"

namespace sentaku::shell::services {

class ServiceRef : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(sentaku::shell::services::Service* service READ service WRITE setService NOTIFY serviceChanged)

public:
    explicit ServiceRef(Service* service = nullptr, QObject* parent = nullptr);

    [[nodiscard]] Service* service() const;
    void setService(Service* service);

signals:
    void serviceChanged();

private:
    QPointer<Service> m_service;
};

} // namespace sentaku::shell::services
