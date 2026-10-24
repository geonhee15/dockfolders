#!/bin/zsh
# Preset: Minimal
# Focus: just the essentials, 4 folders only

CATEGORIES=(
    "01.Work|💼|Mail,Calendar,Notion,Slack,zoom.us"
    "02.Web|🌐|Google Chrome,Safari,Firefox"
    "03.Media|🎬|Spotify,Apple Music,YouTube,Photos,QuickTime Player"
    "04.Utils|🔧|App Store,System Settings,Finder,Activity Monitor,Calculator"
)

FAVORITES=(
    "Launchpad"
    "Google Chrome"
    "Mail"
)

ICON_FALLBACK=(
    "Work|Notion"
    "Web|Google Chrome"
    "Media|Spotify"
    "Utils|System Settings"
)

DOCK_FOLDERS_DIR="$HOME/Applications/DockFolders"
BACKUP_DIR="$HOME/Desktop"
USE_SPACER=true
