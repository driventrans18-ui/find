import Foundation

enum Constants {
    enum Network {
        static let googleLensUploadURL = "https://lens.google.com/upload"
        static let yandexSearchURL = "https://yandex.com/images/search"
        static let pimEyesUploadURL = "https://pimeyes.com/api/upload/file"
        static let pimEyesSearchURL = "https://pimeyes.com/api/search/new"
        static let pimEyesStatusURL = "https://pimeyes.com/api/search/status"
        static let requestTimeout: TimeInterval = 30
        static let pollInterval: TimeInterval = 2
        static let maxPollAttempts = 15
    }

    enum Image {
        static let maxFileSizeBytes = 1_048_576
        static let faceDetectionPadding = 0.15
        static let jpegCompressionStart = 0.9
        static let jpegCompressionStep = 0.1
    }

    enum Storage {
        static let sessionsFileName = "sessions.json"
    }

    enum UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let iconSize: CGFloat = 28
    }

    static let knownSocialDomains: [String] = [
        "facebook.com", "fb.com",
        "instagram.com",
        "twitter.com", "x.com",
        "linkedin.com",
        "tiktok.com",
        "youtube.com", "youtu.be",
        "pinterest.com",
        "reddit.com",
        "vk.com",
        "ok.ru",
        "snapchat.com",
        "tumblr.com",
        "flickr.com",
        "behance.net",
        "github.com"
    ]
}
