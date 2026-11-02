#if canImport(UIKit)
import Ledjer
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@testable import AppCore

/// The devices every screen is snapshotted on. Rendering also depends on the simulator's iOS version,
/// so the tests always run on the simulator `scripts/test.sh` names.
@MainActor let snapshotDevices: [(name: String, config: ViewImageConfig)] = [
    ("iPhone", .iPhone13Pro),
    ("iPad", .iPadPro11(.portrait)),
]

/// Snapshots `screen` on every device in `snapshotDevices`, hosted as `RootView` would host it.
///
/// The first run records the images under `__Snapshots__/` next to the test and fails; look at them,
/// compare them with the board's screen (or the Figma frame), fix the screen and record again by
/// deleting the image. Later runs compare against the recorded images.
@MainActor
func assertScreenSnapshots<Screen: View>(
    of screen: Screen,
    system: AppSystem,
    named name: String,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    for device in snapshotDevices {
        let host = UIHostingController(rootView: ScreenHost(system: system) { screen })
        assertSnapshot(
            of: host, as: .image(on: device.config), named: "\(name)-\(device.name)",
            fileID: fileID, file: filePath, testName: testName, line: line, column: column)
    }
}
#endif
