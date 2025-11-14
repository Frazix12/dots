import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io as Io

FloatingWindow {
	id: wallpaperWindow
	title: "Wallpaper Picker"
	implicitWidth: 900
	implicitHeight: 600
	color: "#ae151217" // background with transparency

	// Color scheme from colors.css
	readonly property color colorBackground: "#151217"
	readonly property color colorSurface: "#221e24"
	readonly property color colorSurfaceContainer: "#2c292e"
	readonly property color colorOnSurface: "#e8e0e8"
	readonly property color colorPrimary: "#dcb9f8"
	readonly property color colorError: "#ffb4ab"
	readonly property color colorOutline: "#4a454d"

	// Configuration
	property string wallpaperDir: "/home/frazix/Pictures/wall"
	property string thumbnailDir: "/tmp/chwall_thumbnails"
	property var wallpapers: []
	property string selectedWallpaper: ""
	property string lastError: ""
	property int maxConcurrentLoads: 4
	property int loadedCount: 0

	// Process for creating thumbnails
	Io.Process {
		id: thumbnailProcess
		command: []
		onExited: function(exitCode, exitStatus) {
			if (exitCode === 0) {
				console.log("Thumbnails generated successfully")
			} else {
				console.log("Thumbnail generation completed with status: " + exitStatus)
			}
			// Start listing wallpapers after thumbnails are generated
			listProcess.running = true
		}
	}

	// Process for executing matugen
	Io.Process {
		id: matugenProcess
		command: []
			onExited: function(exitCode, exitStatus) {
				if (exitCode === 0) {
					showNotification("Wallpaper Applied", "Wallpaper '" + selectedWallpaper + "' applied successfully", "dialog-information")
					wallpaperWindow.visible = false
					Qt.quit()
				} else {
					lastError = "Failed to apply wallpaper"
					showNotification("Error", lastError, "dialog-error")
				}
			}
	}

	// Process for listing wallpapers
	Io.Process {
		id: listProcess
		command: ["sh", "-c", "find '" + wallpaperDir + "' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) | sort"]
		stdout: Io.StdioCollector {
			id: listCollector
		}
		onExited: function(exitCode, exitStatus) {
			if (exitCode !== 0) {
				lastError = "Failed to scan wallpaper directory"
				showNotification("Error", lastError, "dialog-error")
			} else {
				// Parse the output
				let files = listCollector.text.trim().split("\n").filter(f => f.length > 0)
				files = files.map(f => f.split("/").pop()).filter(f => f.length > 0)
				wallpapers = files
				if (wallpapers.length === 0) {
					lastError = "No wallpapers found in " + wallpaperDir
					showNotification("Error", lastError, "dialog-error")
				} else {
					wallpaperGridView.model = wallpapers
				}
			}
		}
	}

	// Check if directory and matugen exist
	Component.onCompleted: {
		// Create thumbnail directory
		let setupCmd = "mkdir -p '" + thumbnailDir + "' && find '" + wallpaperDir + "' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) -exec bash -c 'for f; do thumb=\"" + thumbnailDir + "/$(basename \"$f\").png\"; [ ! -f \"$thumb\" ] && ffmpeg -i \"$f\" -vf \"scale=250:140:force_original_aspect_ratio=decrease,pad=250:140:(ow-iw)/2:(oh-ih)/2\" -q:v 5 \"$thumb\" 2>/dev/null || true; done' _ {} +"
		thumbnailProcess.exec(["sh", "-c", setupCmd])
	}

	function showNotification(title, message, icon) {
		// In a real implementation, you would use a notification service
		console.log("[" + title + "] " + message)
	}

	function applyWallpaper(wallpaperName) {
		selectedWallpaper = wallpaperName
		let fullPath = wallpaperDir + "/" + wallpaperName
		matugenProcess.exec(["matugen", "image", fullPath])
	}

	ColumnLayout {
		anchors.fill: parent
		anchors.margins: 16
		spacing: 12

		Keys.onEscapePressed: wallpaperWindow.visible = false

		// Header
		RowLayout {
			Layout.fillWidth: true

		Text {
			text: "Select a Wallpaper"
			font.pixelSize: 24
			font.bold: true
			color: colorOnSurface
			Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
		}			Item { Layout.fillWidth: true }
		}

		// Error message
		Rectangle {
			visible: lastError !== ""
			color: colorError
			radius: 4
			height: 40
			Layout.fillWidth: true

			Text {
				text: lastError
				color: colorOnSurface
				anchors.centerIn: parent
				font.pixelSize: 12
			}
		}

		// Wallpaper grid
		ScrollView {
			Layout.fillWidth: true
			Layout.fillHeight: true
			contentWidth: wallpaperGrid.width

			GridLayout {
				id: wallpaperGrid
				width: wallpaperWindow.width - 32
				// Larger 16:9 thumbnails
				columns: Math.max(1, Math.floor(width / 260))
				rowSpacing: 16
				columnSpacing: 16
				Layout.fillHeight: true
				Layout.fillWidth: true

				Repeater {
					id: wallpaperGridView
					model: wallpapers

					Rectangle {
						id: wallpaperItem
						width: (wallpaperGrid.width - (wallpaperGrid.columns - 1) * wallpaperGrid.columnSpacing) / wallpaperGrid.columns
						height: width * 9 / 16
						color: colorSurface
						radius: 8
						border.color: selectedWallpaper === modelData ? colorPrimary : "transparent"
						border.width: 2

						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							onClicked: {
								selectedWallpaper = modelData
								applyWallpaper(modelData)
							}
						}

						// Wallpaper preview
						Image {
							anchors.fill: parent
							anchors.margins: 8
							source: "file://" + thumbnailDir + "/" + modelData + ".png"
							fillMode: Image.PreserveAspectCrop
							smooth: false
							asynchronous: true
							cache: true

							onStatusChanged: {
								if (status === Image.Error) {
									source = "file://" + wallpaperDir + "/" + modelData
								}
							}

							BusyIndicator {
								anchors.centerIn: parent
								running: parent.status === Image.Loading
								width: 40
								height: 40
								contentItem.visible: running
							}
						}

						// Wallpaper name
						Rectangle {
							width: parent.width
							height: 30
							color: "#00000066"
							anchors.bottom: parent.bottom
							anchors.left: parent.left
							anchors.right: parent.right
							radius: 0

							Text {
								text: modelData
								color: colorOnSurface
								font.pixelSize: 10
								elide: Text.ElideRight
								anchors.fill: parent
								anchors.margins: 4
								verticalAlignment: Text.AlignVCenter
								horizontalAlignment: Text.AlignHCenter
							}
						}

						// Checkmark for selected
						Rectangle {
							visible: selectedWallpaper === modelData
							width: 24
							height: 24
							radius: 12
							color: colorPrimary
							anchors.top: parent.top
							anchors.right: parent.right
							anchors.margins: 4

							Text {
								text: "✓"
								color: colorBackground
								font.bold: true
								font.pixelSize: 16
								anchors.centerIn: parent
							}
						}
					}
				}
			}
		}

		// Status text
	Text {
		text: wallpapers.length > 0 ? `Loaded ${wallpapers.length} wallpapers` : "Loading wallpapers..."
		font.pixelSize: 11
		color: colorOutline
		Layout.alignment: Qt.AlignRight | Qt.AlignBottom
	}
	}
}
