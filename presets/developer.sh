#!/bin/zsh
# Preset: Developer
# Focus: coding, DevOps, productivity

CATEGORIES=(
    "01.Editors|💻|Visual Studio Code,Cursor,Sublime Text,Zed,Neovim,IntelliJ IDEA,PyCharm,WebStorm,RubyMine,GoLand,Xcode,Android Studio"
    "02.Terminal|⌨️|Warp,iTerm2,Terminal,Alacritty,Kitty,Tabby,Hyper"
    "03.DevOps|🐳|Docker,OrbStack,Lens,Kubernetes,Postman,Insomnia,TablePlus,Sequel Pro,DBeaver,Redis Insight"
    "04.AI|🤖|Claude,ChatGPT,Cursor,Copilot,Ollama"
    "05.Browsers|🌐|Google Chrome,Firefox,Safari,Arc,Brave Browser,Microsoft Edge"
    "06.Comms|💬|Slack,Discord,Microsoft Teams,Zoom,Mail,Telegram,WhatsApp"
    "07.Notes|📝|Notion,Obsidian,Bear,Craft,Logseq,Apple Notes"
    "08.Design|🎨|Figma,Sketch,Adobe XD,Affinity Designer,Pixelmator Pro"
    "09.Utils|🔧|1Password,Raycast,Alfred,CleanMyMac,Bartender,Rectangle,The Unarchiver"
)

FAVORITES=(
    "Launchpad"
    "Cursor"
    "Warp"
    "Google Chrome"
    "Claude"
    "Slack"
)

ICON_FALLBACK=(
    "Editors|Visual Studio Code"
    "Terminal|Warp"
    "DevOps|Docker"
    "AI|Claude"
    "Browsers|Google Chrome"
    "Comms|Slack"
    "Notes|Notion"
    "Design|Figma"
    "Utils|1Password"
)

DOCK_FOLDERS_DIR="$HOME/Applications/DockFolders"
BACKUP_DIR="$HOME/Desktop"
USE_SPACER=true
