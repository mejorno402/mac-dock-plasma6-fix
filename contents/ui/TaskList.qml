/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.core as PlasmaCore

Item {
    id: taskListRoot

    property var model
    property bool vertical: false
    property int panelLocation: 4  // PlasmaCore.Types.BottomEdge default
    property int panelThickness: 48
    property bool zoomEnabled: true
    property real zoomFactor: 1.5
    property int zoomDuration: 150
    property bool zoomNeighbors: true
    property real neighborZoomFactor: 1.2
    property int iconSpacing: 1
    property bool widgetHovered: false
    property bool parabolicEnabled: true
    property int maxParabolicRise: 12

    // Audio
    property var pulseAudio: null

    property int hoveredIndex: -1

    // Continuous mouse position for smooth zoom transitions
    property real mousePos: -1  // Position along the icon row (x for horizontal, y for vertical)
    property bool mouseInArea: false

    // Tracks whether mouse has moved recently (to distinguish "left" from "stationary")
    property bool mouseMovedRecently: false

    // Drag state
    property int dragSourceIndex: -1
    property bool dragInProgress: false

    // Helper to get audio streams for a task
    function audioStreamsForTask(modelIndex) {
        if (!pulseAudio) return [];

        const start = modelIndex;
        const start_row = model.index(modelIndex, 0);

        const start_pid = model.data(start_row, TaskManager.AbstractTasksModel.AppPid) || 0;
        const start_appName = model.data(start_row, TaskManager.AbstractTasksModel.AppName) || "";

        let start_streams = [];

        if (start_pid > 0) {
            start_streams = pulseAudio.streamsForPid(start_pid);
            if (start_streams.length === 0 && start_appName.length > 0) {
                start_streams = pulseAudio.streamsForAppName(start_appName);
            }
        }

        return start_streams;
    }

    // Reset hover state
    function resetHoverState() {
        taskListRoot.hoveredIndex = -1;
        taskListRoot.mouseInArea = false;
        taskListRoot.mousePos = -1;
        taskListRoot.mouseMovedRecently = false;
    }

    // Force reset from parent (called by HoverHandler in main.qml)
    function forceResetHover() {
        activityTimer.stop();
        resetHoverState();
    }

    // Two-phase exit detection that doesn't rely on onExited or containsMouse:
    //
    // Phase 1: activityTimer fires 250ms after last mouse movement.
    //          Sets mouseMovedRecently=false and starts confirmTimer.
    //
    // Phase 2: confirmTimer fires 100ms later. If mouseMovedRecently
    //          is still false (no new movement), reset hover state.
    //          If mouse moved in between, it was just a pause — keep zoom.

    Timer {
        id: activityTimer
        interval: 250
        onTriggered: {
            taskListRoot.mouseMovedRecently = false;
            confirmTimer.start();
        }
    }

    Timer {
        id: confirmTimer
        interval: 100
        onTriggered: {
            if (!taskListRoot.mouseMovedRecently && !taskListRoot.widgetHovered) {
                resetHoverState();
            }
        }
    }

    // Update audio streams when PulseAudio streams change
    Connections {
        target: pulseAudio
        function onStreamsChanged() {
            // Force re-evaluation of audioStreams for all tasks
            for (let i = 0; i < taskRepeater.count; i++) {
                const task = taskRepeater.itemAt(i);
                if (task) {
                    task.audioStreams = taskListRoot.audioStreamsForTask(i);
                }
            }
        }
    }

    signal taskClicked(int index, int button, int modifiers)
    signal taskContextMenu(int index)
    signal taskFilesDropped(int index, var urls)

    function getTaskAt(index) {
        return taskRepeater.itemAt(index);
    }

    readonly property int effectiveIconSize: panelThickness
    readonly property int itemSpacing: Kirigami.Units.smallSpacing * iconSpacing

    // Fixed implicit size based on item count - completely static
    readonly property int contentSize: taskRepeater.count * effectiveIconSize + Math.max(0, taskRepeater.count - 1) * itemSpacing

    implicitWidth: vertical ? panelThickness : contentSize
    implicitHeight: vertical ? contentSize : panelThickness

    // Volume popup dialog
    property var volumeDialog: null
    readonly property Component volumePopupComponent: Qt.createComponent("VolumePopup.qml")

    function showVolumePopup(taskIndex, percent) {
        var task = taskRepeater.itemAt(taskIndex);
        if (!task) return;

        if (volumeDialog) {
            volumeDialog.volumePercent = percent;
            volumeDialog.restartHideTimer();
            return;
        }

        if (volumePopupComponent.status !== Component.Ready) {
            console.log("VolumePopup component error:", volumePopupComponent.errorString());
            return;
        }

        volumeDialog = volumePopupComponent.createObject(taskListRoot, {
            visualParent: task,
            volumePercent: percent,
        });

        if (!volumeDialog) {
            console.log("VolumePopup creation failed");
            return;
        }

        volumeDialog.onVisibleChanged.connect(function() {
            if (volumeDialog && !volumeDialog.visible) {
                volumeDialog.destroy();
                volumeDialog = null;
            }
        });
    }

    // Container for manually positioned tasks - no layout recalculations
    Item {
        id: taskContainer
        anchors.fill: parent

        Repeater {
            id: taskRepeater
            model: taskListRoot.model

            delegate: Task {
                id: taskDelegate

                required property var model
                required property int index

                // Manual positioning - no layout involvement
                x: vertical ? (taskListRoot.width - width) / 2 : index * (effectiveIconSize + itemSpacing)
                y: vertical ? index * (effectiveIconSize + itemSpacing) : (taskListRoot.height - height) / 2

                vertical: taskListRoot.vertical
                panelLocation: taskListRoot.panelLocation
                taskIndex: index
                iconSource: model.decoration
                taskName: model.display || ""
                isActive: model.IsActive || false
                isMinimized: model.IsMinimized || false
                isLauncher: model.IsLauncher || false
                isDemandingAttention: model.IsDemandingAttention || false
                isGroupParent: model.IsGroupParent || false

                // Audio properties
                maxVolume: taskListRoot.pulseAudio ? taskListRoot.pulseAudio.normalVolume : 65536
                volumeStep: Math.round(maxVolume * 0.05)  // 5% per scroll step

                // Audio streams for this task
                audioStreams: taskListRoot.audioStreamsForTask(index)

                baseSize: taskListRoot.effectiveIconSize
                zoomEnabled: taskListRoot.zoomEnabled
                maxZoomFactor: taskListRoot.zoomFactor
                zoomDuration: taskListRoot.zoomDuration
                isTransitioning: taskListRoot.mouseInArea
                parabolicEnabled: taskListRoot.parabolicEnabled
                maxParabolicRise: taskListRoot.maxParabolicRise

                targetZoom: {
                    if (!taskListRoot.zoomEnabled) return 1.0;
                    if (!taskListRoot.mouseInArea || taskListRoot.mousePos < 0) return 1.0;

                    // Calculate center position of this icon
                    var itemSize = effectiveIconSize + itemSpacing;
                    var iconCenter = index * itemSize + effectiveIconSize / 2;

                    // Distance from mouse to icon center (in pixels)
                    var pixelDistance = Math.abs(taskListRoot.mousePos - iconCenter);

                    // Normalize distance: 0 = at center, 1 = one full icon away
                    var normalizedDistance = pixelDistance / itemSize;

                    // Smoothstep function for continuous transitions
                    function smoothstep(edge0, edge1, x) {
                        var t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
                        return t * t * (3 - 2 * t);
                    }

                    // Define key points for interpolation
                    var maxZoom = taskListRoot.zoomFactor;
                    var borderZoom = taskListRoot.zoomNeighbors ? taskListRoot.neighborZoomFactor : 1.0;
                    var maxDist = taskListRoot.zoomNeighbors ? 2.5 : 0.5;

                    if (normalizedDistance <= 0.5) {
                        // Inside main icon: smooth from maxZoom to borderZoom
                        var t = smoothstep(0, 0.5, normalizedDistance);
                        return maxZoom + (borderZoom - maxZoom) * t;
                    } else if (normalizedDistance <= maxDist) {
                        // Neighbor icons: smooth from borderZoom to 1.0
                        var t = smoothstep(0.5, maxDist, normalizedDistance);
                        return borderZoom + (1.0 - borderZoom) * t;
                    }

                    return 1.0;
                }

                targetRise: {
                    if (!taskListRoot.parabolicEnabled) return 0;
                    if (!taskListRoot.mouseInArea || taskListRoot.mousePos < 0) return 0;

                    var itemSize = effectiveIconSize + itemSpacing;
                    var iconCenter = index * itemSize + effectiveIconSize / 2;
                    var pixelDistance = Math.abs(taskListRoot.mousePos - iconCenter);
                    var normalizedDistance = pixelDistance / itemSize;

                    // Smoothstep function
                    function smoothstep(edge0, edge1, x) {
                        var t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
                        return t * t * (3 - 2 * t);
                    }

                    var maxDist = 2.5;
                    if (normalizedDistance <= maxDist) {
                        var t = smoothstep(0, maxDist, normalizedDistance);
                        return taskListRoot.maxParabolicRise * (1 - t);
                    }
                    return 0;
                }

                onHoveredChanged: {
                    if (hovered) {
                        taskListRoot.mouseMovedRecently = true;
                        activityTimer.restart();
                        taskListRoot.hoveredIndex = index;
                        taskListRoot.mouseInArea = true;
                        // Initialize mousePos to icon center to prevent stale position bug
                        var itemSize = effectiveIconSize + itemSpacing;
                        taskListRoot.mousePos = index * itemSize + effectiveIconSize / 2;
                    } else if (taskListRoot.hoveredIndex === index) {
                        activityTimer.restart();
                    }
                }

                onMouseMoved: function(localX, localY) {
                    // Convert local position to global position in the task list
                    var itemSize = effectiveIconSize + itemSpacing;
                    var globalPos;
                    if (vertical) {
                        globalPos = index * itemSize + localY;
                    } else {
                        globalPos = index * itemSize + localX;
                    }
                    taskListRoot.mousePos = globalPos;

                    // Handle drag reordering
                    if (isDragging && taskListRoot.dragInProgress) {
                        var targetIdx = Math.floor(globalPos / itemSize);
                        targetIdx = Math.max(0, Math.min(targetIdx, taskRepeater.count - 1));
                        if (targetIdx !== taskListRoot.dragSourceIndex) {
                            var sourceModelIndex = taskListRoot.model.makeModelIndex(taskListRoot.dragSourceIndex);
                            var targetModelIndex = taskListRoot.model.makeModelIndex(targetIdx);
                            taskListRoot.model.move(taskListRoot.dragSourceIndex, targetIdx);
                            taskListRoot.dragSourceIndex = targetIdx;
                        }
                    }
                }

                onClicked: function(button, modifiers) {
                    taskListRoot.taskClicked(index, button, modifiers);
                }

                onContextMenuRequested: {
                    taskListRoot.taskContextMenu(index);
                }

                onVolumeChanged: function(percent) {
                    taskListRoot.showVolumePopup(index, percent);
                }

                onDragStarted: {
                    taskListRoot.dragSourceIndex = index;
                    taskListRoot.dragInProgress = true;
                }

                onIsDraggingChanged: {
                    if (!isDragging && taskListRoot.dragInProgress) {
                        taskListRoot.dragInProgress = false;
                        taskListRoot.dragSourceIndex = -1;
                        // Sync launchers to persist the new order
                        taskListRoot.model.syncLaunchers();
                    }
                }

                onFilesDropped: function(urls) {
                    taskListRoot.taskFilesDropped(index, urls);
                }
            }
        }

        // Sensor global de movimiento
        MouseArea {
            id: globalMouseArea
            anchors.fill: parent
            hoverEnabled: true
            // Línea clave 1: No aceptamos botones para que el clic 'atraviese' esta capa
            acceptedButtons: Qt.NoButton
            // Línea clave 2: Permitimos que el evento siga bajando a los iconos
            propagateComposedEvents: true
            // Línea clave 3: Z alto para calcular el zoom de todos, pero sin bloquear
            z: 1000

            onPositionChanged: function(mouse) {
                taskListRoot.mouseMovedRecently = true;
                activityTimer.restart();
                taskListRoot.mouseInArea = true;
                taskListRoot.mousePos = vertical ? mouse.y : mouse.x;

                var itemSize = effectiveIconSize + itemSpacing;
                var idx = Math.floor((vertical ? mouse.y : mouse.x) / itemSize);
                if (idx >= 0 && idx < taskRepeater.count) {
                    // Actualizamos el índice global para que el icono sepa que está bajo el mouse
                    taskListRoot.hoveredIndex = idx;
                }
            }

            onExited: {
                activityTimer.stop();
                confirmTimer.stop();
                resetHoverState();
            }

            // EL MASTER TOOLTIP: Ahora configurado como "Fantasma"
            PlasmaCore.ToolTipArea {
                id: masterToolTip

                // LA CLAVE MAGISTRAL: Tamaño CERO.
                // Así el motor de Plasma sabe dónde poner el texto, pero el ratón NUNCA choca con la caja.
                width: 0
                height: 0

                // Matemáticas para centrar ese punto invisible exactamente en el medio del icono activo
                x: vertical ? 0 : (taskListRoot.hoveredIndex * (effectiveIconSize + itemSpacing)) + (effectiveIconSize / 2)
                y: vertical ? (taskListRoot.hoveredIndex * (effectiveIconSize + itemSpacing)) + (effectiveIconSize / 2) : 0

                // Z máximo para que la ventana emerja sobre el dock
                z: 9999

                // Extraemos la información del icono actual usando el índice
                property var currentTask: taskListRoot.hoveredIndex !== -1 ? taskRepeater.itemAt(taskListRoot.hoveredIndex) : null

                // Lo encendemos solo cuando el ratón toca un icono válido
                active: taskListRoot.hoveredIndex !== -1

                // Mostramos los datos del icono actual
                mainText: currentTask ? currentTask.taskName : ""
                subText: currentTask && currentTask.isLauncher ? "Clic para abrir" : ""
                icon: currentTask ? currentTask.iconSource : ""
                location: taskListRoot.panelLocation
            }
        }
    } // Cierra el taskContainer (Item)
} // Cierra el taskListRoot (Item)
