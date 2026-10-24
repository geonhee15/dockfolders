#!/bin/zsh
# Preset: Student
# Focus: study, productivity, communication

CATEGORIES=(
    "01.Office|📝|Pages,Numbers,Keynote,Microsoft Word,Microsoft Excel,Microsoft PowerPoint,Google Docs"
    "02.Notes|📓|Notion,Obsidian,GoodNotes,Notability,OneNote,Bear,Apple Notes"
    "03.Research|🔬|Zotero,Mendeley,Citation,Papers,Adobe Acrobat Reader,Preview"
    "04.Web|🌐|Google Chrome,Safari,Firefox,Microsoft Edge"
    "05.AI|🤖|Claude,ChatGPT,Perplexity"
    "06.Study|🎓|Anki,Quizlet,Khan Academy,Coursera,Wolfram Mathematica,GeoGebra,TI Connect CE"
    "07.Comms|💬|Mail,Slack,Discord,Microsoft Teams,zoom.us,KakaoTalk,Messages"
    "08.Creative|🎨|GarageBand,iMovie,Pixelmator Pro,Procreate,Figma"
    "09.Fun|🎮|Spotify,Apple Music,YouTube,Netflix,Steam,Minecraft"
)

FAVORITES=(
    "Launchpad"
    "Google Chrome"
    "Notion"
    "Claude"
    "Mail"
)

ICON_FALLBACK=(
    "Office|Pages"
    "Notes|Notion"
    "Research|Zotero"
    "Web|Google Chrome"
    "AI|Claude"
    "Study|Anki"
    "Comms|Mail"
    "Creative|GarageBand"
    "Fun|Spotify"
)

DOCK_FOLDERS_DIR="$HOME/Applications/DockFolders"
BACKUP_DIR="$HOME/Desktop"
USE_SPACER=true
