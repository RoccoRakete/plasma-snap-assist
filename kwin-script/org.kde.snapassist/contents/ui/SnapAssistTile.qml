import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kwin

// One selectable tile in the Snap Assist grid: a live thumbnail of another
// open window plus its title. KWin.WindowThumbnail bound via wId is the
// pattern the shipped window-switcher (thumbnail_grid) uses for live window
// previews.
MouseArea {
    id: tile

    property var windowObject: null
    property bool isCurrent: false

    signal activated()

    hoverEnabled: true
    onClicked: tile.activated()

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: Kirigami.Theme.backgroundColor
        border.width: tile.isCurrent || tile.containsMouse ? 2 : 1
        border.color: tile.isCurrent || tile.containsMouse ? Kirigami.Theme.highlightColor : Kirigami.Theme.separatorColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: tile.windowObject ? tile.windowObject.icon : ""
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 5
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
                text: tile.windowObject ? tile.windowObject.caption : ""
            }
        }

        WindowThumbnail {
            id: thumb
            Layout.fillWidth: true
            Layout.fillHeight: true
            wId: tile.windowObject ? tile.windowObject.internalId : ""
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: tile.windowObject ? tile.windowObject.caption : ""

    Keys.onReturnPressed: tile.activated()
}
