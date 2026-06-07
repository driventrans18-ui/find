import Foundation

struct TelegramSearchResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let username: String?       // @handle, nil for private
    let description: String
    let subscriberCount: String // "12.4K", "1.2M", etc.
    let type: ChannelType
    let avatarURL: URL?
    let tgstatURL: URL
    let telegramURL: URL?       // tg://resolve?domain=… or t.me/…

    enum ChannelType: String {
        case channel = "Channel"
        case group   = "Group"
        case bot     = "Bot"
    }
}
