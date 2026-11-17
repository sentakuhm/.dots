qml_module(sentaku-models
    URI Sentaku.Models
    SOURCES
        filesystemmodel.cpp
        appdb.cpp
    LIBRARIES
        Qt::Gui
        Qt::Multimedia
        Qt::Concurrent
        Qt::Sql
)
