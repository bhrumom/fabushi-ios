import Foundation

let MCP_CUSTOM_INSTRUCTIONS_MAX_LENGTH = 500

private let DEFAULT_MCP_CONNECTOR_INSTRUCTIONS: [String: String] = [
    "hex": "When using Hex, work from the connector's underlying exported/raw data rather than reading values from chart screenshots.",
]

struct McpCustomInstructionEntry: Equatable, Sendable {
    let name: String
    let instructions: String
}

func clampMcpCustomInstruction(_ raw: String) -> String {
    String(raw.prefix(MCP_CUSTOM_INSTRUCTIONS_MAX_LENGTH))
}

func getDefaultMcpCustomInstruction(_ serverName: String) -> String {
    DEFAULT_MCP_CONNECTOR_INSTRUCTIONS[serverName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? ""
}

func resolveMcpCustomInstruction(
    _ serverName: String,
    storedInstruction: String?
) -> String {
    if let storedInstruction {
        return storedInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return getDefaultMcpCustomInstruction(serverName)
}

func formatMcpCustomInstructionToolNote(
    _ serverName: String,
    instructions: String
) -> String {
    """
    Custom instructions for the "\(serverName)" connector (always follow them when using this tool):
    \(instructions.trimmingCharacters(in: .whitespacesAndNewlines))
    """
}

func selectConnectedMcpCustomInstructions(
    _ connectedServerNames: [String],
    instructionsByServer: [String: String]
) -> [McpCustomInstructionEntry] {
    var seen = Set<String>()
    var entries: [McpCustomInstructionEntry] = []
    for name in connectedServerNames where seen.insert(name).inserted {
        let instructions = resolveMcpCustomInstruction(name, storedInstruction: instructionsByServer[name])
        if !instructions.isEmpty {
            entries.append(.init(name: name, instructions: instructions))
        }
    }
    return entries.sorted { $0.name < $1.name }
}

func buildMcpCustomInstructionsSystemPromptSection(
    _ connectedServerNames: [String],
    instructionsByServer: [String: String]
) -> String? {
    let entries = selectConnectedMcpCustomInstructions(
        connectedServerNames,
        instructionsByServer: instructionsByServer
    )
    guard !entries.isEmpty else { return nil }
    return ([
        "## Connector custom instructions",
        "Custom instructions are configured for some connected tools (MCP connectors). Always follow the matching instruction whenever you use that connector's tools, even before your first call to it:",
    ] + entries.map { "- \($0.name): \($0.instructions)" }).joined(separator: "\n")
}
