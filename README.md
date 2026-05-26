# 📁 DockFolders

> macOS Dock category organizer with emoji icons
> Organize your apps into beautiful categorized folders in the Dock.

<img src="https://img.shields.io/badge/macOS-12%2B-blue" alt="macOS 12+">
<img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
<img src="https://img.shields.io/badge/version-1.0.0-orange" alt="v1.0.0">

---

## 🇰🇷 한국어

### 무엇을 하는가?

맥 Dock에 흩어진 수십 개의 앱을 **카테고리 폴더**로 정리합니다. 각 폴더는 **이모지 아이콘**으로 표시되어 한눈에 구분 가능. 원본 앱은 건드리지 않고 **심볼릭 링크**만 만들어요.

### 설치

```bash
git clone https://github.com/Geonhee15/dockfolders.git
cd dockfolders
./install.sh
```

### 사용법

```bash
# 1. 설정 편집
$EDITOR ~/.config/dockfolders/config.sh

# 2. 정리 실행
dockfolders organize

# 3. 미분류 앱 확인
dockfolders discover

# 4. 원래대로 복구
dockfolders reset
```

### 프리셋

```bash
dockfolders preset developer   # 개발자용
dockfolders preset creator     # 컨텐츠 크리에이터
dockfolders preset student     # 학생
dockfolders preset minimal     # 미니멀
```

### 커스터마이징

`~/.config/dockfolders/config.sh` 편집:

```bash
CATEGORIES=(
    "01.Dev|💻|Cursor,Visual Studio Code,Warp"
    "02.AI|🤖|Claude,ChatGPT"
    "03.Web|🌐|Google Chrome,Firefox"
)

FAVORITES=("Launchpad" "Cursor" "Chrome")
```

포맷: `폴더이름|이모지|앱1,앱2,앱3`

### 작동 원리

1. **`~/Applications/DockFolders/`** 안에 카테고리 폴더 생성
2. 각 폴더에 앱의 심볼릭 링크 생성 (원본 앱은 그대로)
3. **Apple Color Emoji**를 Python Pillow로 1024px PNG로 렌더링
4. **fileicon**으로 폴더에 아이콘 적용
5. **dockutil**로 Dock 재구성 (즐겨찾기 + 스페이서 + 폴더)

---

## 🇺🇸 English

### What it does

Organizes your scattered Mac apps into **categorized folders** in the Dock with **emoji icons**. Originals are never touched — only **symlinks** are created.

### Install

```bash
git clone https://github.com/Geonhee15/dockfolders.git
cd dockfolders
./install.sh
```

Or one-liner (after publishing to GitHub):

```bash
curl -fsSL https://raw.githubusercontent.com/Geonhee15/dockfolders/main/install.sh | zsh
```

### Usage

```bash
dockfolders organize           # Apply config
dockfolders discover           # Find uncategorized apps
dockfolders preset developer   # Use a preset
dockfolders reset              # Restore Dock from backup
dockfolders help               # Show all commands
```

### Configuration

Edit `~/.config/dockfolders/config.sh`:

```bash
CATEGORIES=(
    "01.Dev|💻|Cursor,Visual Studio Code,Warp,iTerm2"
    "02.AI|🤖|Claude,ChatGPT"
    "03.Web|🌐|Google Chrome,Firefox,Safari"
)

FAVORITES=(
    "Launchpad"
    "Cursor"
    "Google Chrome"
)
```

**Category format:** `FolderName|Emoji|Comma,Separated,App,Names`

App names should match the displayed name or `.app` bundle filename. Apps that aren't installed are skipped silently.

### Presets

- `developer` — Code editors, terminals, DevOps, browsers
- `creator` — Video, audio, design, 3D, streaming
- `student` — Office, notes, research, study apps
- `minimal` — Just 4 folders: Work, Web, Media, Utils

Apply with: `dockfolders preset <name>`

### How it works

1. Creates category folders in `~/Applications/DockFolders/`
2. Symlinks each app into its category (originals stay put)
3. Renders **Apple Color Emoji** to 1024px PNG via Python Pillow
4. Applies icons to folders with **fileicon**
5. Rebuilds Dock with **dockutil**: favorites + spacer + folders

### Requirements

- macOS 12+ (Monterey or later)
- [Homebrew](https://brew.sh)
- The installer auto-installs: `dockutil`, `fileicon`, `pillow`

### Project Structure

```
dockfolders/
├── dockfolders              # Main executable
├── install.sh               # Installer
├── uninstall.sh             # Uninstaller
├── config.example.sh        # Config template
├── presets/                 # Ready-made configs
│   ├── developer.sh
│   ├── creator.sh
│   ├── student.sh
│   └── minimal.sh
├── README.md
└── LICENSE
```

### Backups

Every `organize` run creates a timestamped Dock backup on `~/Desktop/dock_backup_YYYYMMDD_HHMMSS/`. Restore the latest one with:

```bash
dockfolders reset
```

### Uninstall

```bash
./uninstall.sh
```

Removes the script, config, folders, and icon cache. Does **not** uninstall Homebrew tools (run `brew uninstall dockutil fileicon` separately if needed).

### License

MIT — see [LICENSE](LICENSE)

### Credits

Built with:
- [dockutil](https://github.com/kcrawford/dockutil) — Dock manipulation
- [fileicon](https://github.com/mklement0/fileicon) — Set folder icons
- [Pillow](https://python-pillow.org/) — Emoji rendering
