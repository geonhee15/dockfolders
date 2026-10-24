#!/bin/zsh
# Preset: Content Creator
# Focus: video, audio, design, streaming

CATEGORIES=(
    "01.Video|🎬|Final Cut Pro,DaVinci Resolve,Adobe Premiere Pro,Adobe After Effects 2026,iMovie,CapCut,Motion,Compressor,HandBrake"
    "02.Audio|🎵|Logic Pro,GarageBand,Ableton Live,FL Studio 2025,Pro Tools,REAPER,Audacity,Audio Hijack,Loopback"
    "03.Design|🎨|Adobe Photoshop,Adobe Illustrator 2026,Adobe InDesign,Figma,Sketch,Affinity Designer,Affinity Photo,Procreate,Pixelmator Pro"
    "04.3D|🧊|Blender,Cinema 4D,Maya,ZBrush,Maxon Cinema 4D 2026,Substance 3D Painter,KeyShot"
    "05.Streaming|📹|OBS,Streamlabs,Twitch Studio,Restream,Wirecast"
    "06.AI|🤖|Claude,ChatGPT,Midjourney,Runway"
    "07.Stock|📦|Adobe Creative Cloud,Topaz Photo AI,Topaz Video AI"
    "08.Productivity|📝|Notion,Trello,Asana,Notepad,Apple Notes,Calendar"
    "09.Comms|💬|Discord,Slack,Mail,Telegram,WhatsApp,zoom.us"
)

FAVORITES=(
    "Launchpad"
    "Final Cut Pro"
    "Adobe Photoshop"
    "Google Chrome"
    "Discord"
    "Spotify"
)

ICON_FALLBACK=(
    "Video|Final Cut Pro"
    "Audio|Logic Pro"
    "Design|Adobe Photoshop"
    "3D|Blender"
    "Streaming|OBS"
    "AI|Claude"
    "Stock|Adobe Creative Cloud"
    "Productivity|Notion"
    "Comms|Discord"
)

DOCK_FOLDERS_DIR="$HOME/Applications/DockFolders"
BACKUP_DIR="$HOME/Desktop"
USE_SPACER=true
