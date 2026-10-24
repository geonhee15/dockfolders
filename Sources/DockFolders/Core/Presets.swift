import Foundation

/// Built-in starting points (ported from the v1 shell presets, now with colors).
struct Preset: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let folders: [(name: String, emoji: String, apps: [String])]
    let favorites: [String]

    func makeConfig(keeping settings: AppSettings = AppSettings()) -> DockConfig {
        let dockFolders = folders.enumerated().map { i, f in
            DockFolder(name: f.name, icon: IconSpec(emoji: f.emoji, palette: i), apps: f.apps)
        }
        return DockConfig(folders: dockFolders, favorites: favorites, settings: settings)
    }
}

enum Presets {
    static let all: [Preset] = [developer, creator, student, minimal]

    static func named(_ id: String) -> Preset? {
        all.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
    }

    static let developer = Preset(
        id: "developer", name: "Developer", emoji: "💻",
        description: "Editors, terminals, DevOps, AI tools and browsers.",
        folders: [
            ("Editors", "💻", ["Visual Studio Code", "Cursor", "Sublime Text", "Zed", "Neovim", "IntelliJ IDEA", "PyCharm", "WebStorm", "RubyMine", "GoLand", "Xcode", "Android Studio"]),
            ("Terminal", "⌨️", ["Warp", "iTerm2", "Terminal", "Alacritty", "Kitty", "Tabby", "Hyper", "Ghostty"]),
            ("DevOps", "🐳", ["Docker", "OrbStack", "Lens", "Postman", "Insomnia", "TablePlus", "Sequel Pro", "DBeaver", "Redis Insight"]),
            ("AI", "🤖", ["Claude", "ChatGPT", "Copilot", "Ollama", "LM Studio"]),
            ("Browsers", "🌐", ["Google Chrome", "Firefox", "Safari", "Arc", "Brave Browser", "Microsoft Edge"]),
            ("Comms", "💬", ["Slack", "Discord", "Microsoft Teams", "zoom.us", "Mail", "Telegram", "WhatsApp", "Messages"]),
            ("Notes", "📝", ["Notion", "Obsidian", "Bear", "Craft", "Logseq", "Notes"]),
            ("Design", "🎨", ["Figma", "Sketch", "Adobe XD", "Affinity Designer", "Pixelmator Pro"]),
            ("Utils", "🔧", ["1Password", "Raycast", "Alfred", "CleanMyMac", "Bartender", "Rectangle", "The Unarchiver", "System Settings"]),
        ],
        favorites: ["Cursor", "Warp", "Google Chrome", "Claude", "Slack"]
    )

    static let creator = Preset(
        id: "creator", name: "Creator", emoji: "🎬",
        description: "Video, audio, design, 3D and streaming apps.",
        folders: [
            ("Video", "🎬", ["Final Cut Pro", "Adobe Premiere Pro", "DaVinci Resolve", "iMovie", "CapCut", "Adobe After Effects", "Motion", "HandBrake", "QuickTime Player"]),
            ("Audio", "🎧", ["Logic Pro", "GarageBand", "Ableton Live", "FL Studio", "REAPER", "Audacity", "Adobe Audition"]),
            ("Design", "🎨", ["Adobe Photoshop", "Adobe Illustrator", "Affinity Photo", "Affinity Designer", "Figma", "Sketch", "Pixelmator Pro", "Canva"]),
            ("3D", "🧊", ["Blender", "Cinema 4D", "Maya", "Autodesk Fusion", "Unity Hub", "Unreal Engine"]),
            ("Stream", "📡", ["OBS", "Streamlabs", "Elgato Stream Deck", "Discord", "Twitch Studio"]),
            ("Photo", "📷", ["Photos", "Adobe Lightroom", "Adobe Lightroom Classic", "Capture One", "Darktable"]),
            ("Social", "💬", ["Slack", "Discord", "Telegram", "KakaoTalk", "Messages", "Mail"]),
            ("Web", "🌐", ["Google Chrome", "Safari", "Firefox", "Arc"]),
        ],
        favorites: ["Final Cut Pro", "Adobe Photoshop", "Google Chrome", "Discord"]
    )

    static let student = Preset(
        id: "student", name: "Student", emoji: "🎓",
        description: "Office, notes, research and study apps.",
        folders: [
            ("Office", "📝", ["Pages", "Numbers", "Keynote", "Microsoft Word", "Microsoft Excel", "Microsoft PowerPoint", "Google Docs", "LibreOffice"]),
            ("Notes", "📒", ["Notion", "Obsidian", "GoodNotes", "Notability", "Notes", "Bear", "Freeform"]),
            ("Research", "🔬", ["Zotero", "Mendeley Reference Manager", "Papers", "Preview", "Adobe Acrobat Reader", "Kindle"]),
            ("Study", "🎓", ["Anki", "Quizlet", "Duolingo", "Khan Academy", "Wolfram Mathematica", "GeoGebra", "TI Connect CE"]),
            ("Code", "💻", ["Visual Studio Code", "Xcode", "PyCharm", "IntelliJ IDEA", "Terminal"]),
            ("Web", "🌐", ["Safari", "Google Chrome", "Firefox", "Arc"]),
            ("Social", "💬", ["Messages", "Mail", "Discord", "Slack", "KakaoTalk", "zoom.us", "Microsoft Teams"]),
            ("Media", "🎵", ["Music", "Spotify", "TV", "Podcasts", "Photos", "VLC"]),
        ],
        favorites: ["Safari", "Notion", "Mail", "Messages"]
    )

    static let minimal = Preset(
        id: "minimal", name: "Minimal", emoji: "✨",
        description: "Just four folders: Work, Web, Media, Utils.",
        folders: [
            ("Work", "💼", ["Visual Studio Code", "Cursor", "Xcode", "Pages", "Numbers", "Keynote", "Microsoft Word", "Microsoft Excel", "Microsoft PowerPoint", "Notion", "Obsidian", "Slack", "zoom.us"]),
            ("Web", "🌐", ["Safari", "Google Chrome", "Firefox", "Arc", "Brave Browser"]),
            ("Media", "🎵", ["Music", "Spotify", "TV", "Photos", "Podcasts", "VLC", "QuickTime Player"]),
            ("Utils", "🔧", ["System Settings", "App Store", "Terminal", "Calculator", "Activity Monitor", "Disk Utility", "1Password", "Raycast"]),
        ],
        favorites: ["Safari", "Mail", "Messages", "System Settings"]
    )
}
