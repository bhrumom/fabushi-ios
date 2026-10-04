import SwiftUI

internal struct MobileBotSummary: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let description: String
    let miniAppId: String?
    let menuButtonText: String?

    init(
        id: String,
        name: String,
        description: String,
        miniAppId: String? = nil,
        menuButtonText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.miniAppId = miniAppId
        self.menuButtonText = menuButtonText
    }
}
