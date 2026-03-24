import Foundation

let exitCode = CLI.run(
    arguments: Array(CommandLine.arguments.dropFirst()),
    stdout: { FileHandle.standardOutput.write(Data($0.utf8)) },
    stderr: { FileHandle.standardError.write(Data($0.utf8)) }
)
Foundation.exit(exitCode)
