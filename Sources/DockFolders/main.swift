import Foundation
import AppKit

// Entry point: `DockFolders <command>` runs the CLI, anything else launches the GUI.
let arguments = Array(CommandLine.arguments.dropFirst())
if CLI.isCLIInvocation(arguments) {
    exit(CLI.run(arguments))
}
DockFoldersApp.main()
