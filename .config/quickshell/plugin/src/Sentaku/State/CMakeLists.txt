qml_module(sentaku-state
    URI Sentaku.State
    INCLUDE_PREFIX state
    SOURCES
        common.cpp
        rootnodes.cpp
    DEPENDENCIES
        Sentaku.Settings
)
target_link_libraries(sentaku-state PUBLIC sentaku-settings)
