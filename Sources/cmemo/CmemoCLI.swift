import Foundation
import CMemoKit

@main
struct CmemoCLI {
    private static let usage = """
        Usage: cmemo <command>

        Commands:
          record        Read hook JSON from stdin and persist it to the session store
          install       Emit hook configuration for supported agents
          claude-reply  Print the last assistant reply of a session (not yet implemented)
        """

    static func main() {
        guard let command = CommandLine.arguments.dropFirst().first else {
            failWithUsage()
        }
        switch command {
        case "record":
            let input = FileHandle.standardInput.readDataToEndOfFile()
            let store = SessionStore(baseDirectory: SessionStore.defaultBaseDirectory())
            exit(RecordCommand.run(input: input, store: store, now: Date()))
        case "install":
            exit(InstallCommand.run(agent: CommandLine.arguments.dropFirst(2).first ?? ""))
        case "claude-reply":
            FileHandle.standardError.write(Data("cmemo claude-reply: not implemented yet\n".utf8))
            exit(2)
        default:
            failWithUsage()
        }
    }

    private static func failWithUsage() -> Never {
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        exit(2)
    }
}
