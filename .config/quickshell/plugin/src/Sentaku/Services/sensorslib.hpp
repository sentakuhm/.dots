#pragma once

#include <optional>

namespace sentaku::shell::services::sensorslib {

void ensureInit();

[[nodiscard]] std::optional<double> cpuPackageTemp();
[[nodiscard]] std::optional<double> gpuPciAverageTemp();

} // namespace sentaku::shell::services::sensorslib
