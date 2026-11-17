#pragma once

#include "common.hpp"
#include "objectnode.hpp"
#include "settingsfile.hpp"

namespace sentaku::shell::settings {

class RootNode : public ObjectNode {
    Q_OBJECT

    Q_PROPERTY(QList<sentaku::shell::settings::Diagnostic> diagnostics READ diagnostics NOTIFY diagnosticsChanged)

public:
    explicit RootNode(bool watch, const QString& path, RootNode* fallback, QObject* parent = nullptr);

    [[nodiscard]] QList<Diagnostic> diagnostics() const;

    void load();

signals:
    void diagnosticsChanged();
    void treeLoaded(sentaku::shell::settings::RootNode* self);
    void treeLoadFailed(sentaku::shell::settings::RootNode* self, const QString& error);
    void treeSaveFailed(sentaku::shell::settings::RootNode* self, const QString& error);

private:
    SettingsFile* const m_file;
    QList<Diagnostic> m_diagnostics;

    void reloadFromFile();
    void saveToFile();
};

} // namespace sentaku::shell::settings
