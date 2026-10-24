#!/bin/zsh
# ╔══════════════════════════════════════════════╗
# ║   DockFolders Configuration                  ║
# ║   Edit this file to customize your Dock      ║
# ╚══════════════════════════════════════════════╝
#
# Save your edited version at:
#   ~/.config/dockfolders/config.sh
#

# ═══════════════════════════════════════════════
# CATEGORIES
# ═══════════════════════════════════════════════
# Format: "FolderName|Emoji|App1,App2,App3"
#
# • FolderName: Use prefix like "01.", "02." for ordering
# • Emoji: Single emoji character (rendered as folder icon)
# • Apps: Comma-separated app names (no .app extension)
#
# Tips:
# • App name should match the displayed name OR the .app bundle filename
# • For apps not in /Applications, Spotlight will search system-wide
# • Apps that aren't installed are skipped automatically
# • Order within a category is alphabetical in the Dock stack
#
CATEGORIES=(
    "01.Dev|💻|Cursor,Visual Studio Code,Warp,iTerm2,IntelliJ IDEA,Docker,OrbStack,VirtualBox,VMware Fusion,PowerShell"
    "02.AI|🤖|Claude,ChatGPT"
    "03.Web|🌐|Google Chrome,Firefox,Safari,Tor Browser,ProtonVPN"
    "04.Creative|🎨|Adobe After Effects 2026,Adobe Illustrator 2026,Adobe Media Encoder 2026,Adobe Creative Cloud,Blender,Aseprite,iMovie,CapCut,OBS,Audacity,GarageBand,REAPER,FL Studio 2025,QuickTime Player"
    "05.Maker|🔧|Arduino IDE,Processing,Snapmaker Orca,Creality Print,Unity Hub,GameMaker"
    "06.Games|🎮|Minecraft,Roblox,Steam,CurseForge"
    "07.Social|💬|Discord,KakaoTalk,Slack,zoom.us,Mail,FaceTime,Messages"
    "08.Office|📝|Pages,Numbers,Keynote,Freeform,Microsoft Word,Microsoft Excel,Microsoft PowerPoint,Notion,Obsidian"
    "09.School|🎓|AssessPrep,NWEA Secure Testing Browser,TI Connect CE"
)

# ═══════════════════════════════════════════════
# FAVORITES (Dock left side)
# ═══════════════════════════════════════════════
# Apps that stay in the Dock's app area (left of folders).
# Keep this short — 4-6 apps you use constantly.
#
FAVORITES=(
    "Launchpad"
    "Cursor"
    "Google Chrome"
    "Claude"
)

# ═══════════════════════════════════════════════
# ICON FALLBACK (when emoji rendering fails)
# ═══════════════════════════════════════════════
# Format: "CategoryShortName|AppName"
# 
# If Pillow (Python) isn't available, these app icons are used
# instead of emoji. The CategoryShortName is the part after
# the dot in folder names (e.g., "01.Dev" → "Dev").
#
ICON_FALLBACK=(
    "Dev|Visual Studio Code"
    "AI|Claude"
    "Web|Google Chrome"
    "Creative|Adobe After Effects 2026"
    "Maker|Arduino IDE"
    "Games|Minecraft"
    "Social|Discord"
    "Office|Pages"
    "School|AssessPrep"
)

# ═══════════════════════════════════════════════
# SETTINGS
# ═══════════════════════════════════════════════

# Where to create the symlink folders (the actual folders shown in Dock)
DOCK_FOLDERS_DIR="$HOME/Applications/DockFolders"

# Where to save Dock backups before modifications
BACKUP_DIR="$HOME/Desktop"

# Add a visual spacer between favorites and folders
USE_SPACER=true
