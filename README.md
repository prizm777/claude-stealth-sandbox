# Claude Stealth Sandbox for Windows

[English](#english) | [Русский](#русский)

---

<a name="русский"></a>
## Описание на русском

**Claude Stealth Sandbox** — это готовое окружение и интерактивный хаб для безопасной работы с **Claude Desktop** и **Claude Code (CLI)** на Windows. Sandbox полностью изолирует процессы Claude, защищает аккаунт от геоблокировок Anthropic, блокирует утечки WebRTC, подменяет фингерпринт устройства, автоматически устанавливает компоненты и решает проблему зависания процессов в памяти Windows.

![Release](https://img.shields.io/badge/Release-v1.2.0-blue?style=for-the-badge)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue?style=for-the-badge&logo=windows)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Security](https://img.shields.io/badge/Security-Kill--Switch%20Active-brightgreen?style=for-the-badge)

---

### Интерактивное Меню Управления (`start.bat`):

При запуске главного файла `start.bat` открывается удобное интерактивное меню без лишних символов и эмодзи:

```text
======================================================================
               CLAUDE STEALTH SANDBOX FOR WINDOWS
       WebRTC Hardening, Kill-Switch & Anti-Zombie Watchdog
======================================================================
 [*] Текущие привилегии: Обычный пользователь
----------------------------------------------------------------------
  [1] Запустить Claude Desktop (Безопасная песочница)
  [2] Запустить Claude Desktop от имени Администратора
  [3] Запустить Claude Code CLI (Терминал песочницы)
  [4] Проверить статус Proxy / VPN и Kill-Switch
  [5] Проверить защиту от утечек WebRTC и IP в браузере
  [6] Экстренная очистка (выгрузить все процессы и кэш)
  [7] Создать / обновить ярлык на Рабочем столе
  [8] Установить Claude Desktop (сразу с изоляцией)
  [9] Установить Claude Code CLI (Терминал песочницы)

  [0] Выход
----------------------------------------------------------------------
  Выберите действие [0-9]:
```

---

### Ключевые возможности:

1. **Аппаратный Kill Switch:**
   - Автоматически сканирует и находит активный порт Proxy/VPN (Happ, Xray, Sing-box, V2Ray, Clash на портах `10808`, `10809`, `2080`, `7890` или заданный через `$env:CLAUDE_PROXY_PORT`).
   - Перед каждым запуском делает проверочный запрос к внешнему API: если возвращается IP из РФ или прокси отключился — **запуск немедленно блокируется**, предотвращая бан аккаунта.
2. **Защита от утечек WebRTC и телеметрии:**
   - Принудительно отключает непроксированный UDP в Chromium (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`, `--enforce-webrtc-ip-permission-check`).
   - Запрещает сбор телеметрии, краш-дампы и сбор метрик Anthropic (`DISABLE_TELEMETRY=1`, `DO_NOT_TRACK=1`, `DISABLE_GROWTHBOOK=1`, `--disable-breakpad`, `--disable-crash-reporter`).
3. **Спуфинг окружения и фингерпринта:**
   - Подменяет имя компьютера на `MacBook-Air`.
   - Подменяет часовой пояс на `Europe/Berlin`, локаль на `en-US`.
   - Генерирует уникальные случайные 64-символьные `machineID` и `userID`.
   - Изолирует данные профиля в папке `data/` — Claude никогда не читает ваш реальный системный `%USERPROFILE%` или `%APPDATA%`.
4. **Решение бага «В режиме паузы» (Anti-Zombie Watchdog):**
   - В Windows 10/11 приложения UWP/MSIX при закрытии окна сворачиваются в фоновые процессы со статусом **«Приостановлено» (Suspended)** и держат память и сопутствующие процессы `chrome-native-host.exe`.
   - Sandbox автоматически отключает фоновое зависание в реестре Windows (`BackgroundAccessApplications\Claude_pzs8sxrjxfjjc`).
   - В фоне работает скрытый независимый **Watchdog-сторож**: при закрытии окна консоли он за миллисекунды подчистую выгружает все связанные процессы Claude из памяти (0 висячих процессов в Диспетчере задач).
5. **Двойной режим (Обычный / Администратор):**
   - **Обычный запуск:** Безопасный стандартный режим песочницы.
   - **Запуск от имени администратора:** Claude получает токен высокой целостности (High Integrity / RunAs), а для Claude Code CLI автоматически включается `--dangerously-skip-permissions`. Это позволяет Claude взаимодействовать с системными процессами и консолями.
6. **Установка в 1 клик с преднастроенной изоляцией:**
   - **[8] Установить Claude Desktop:** Проверяет наличие клиента в системе; если не установлен — скачивает и устанавливает через `winget` (`Anthropic.Claude`) или официальный инсталлятор. Сразу применяет отключение UWP-зависания, останавливает и отключает фоновую службу `CoworkVMService`, удаляет автозагрузку из реестра, преднастраивает защищенный профиль и создает ярлык на Рабочем столе.
   - **[9] Установить Claude Code CLI:** Проверяет Node.js/npm (устанавливает Node.js LTS при отсутствии), устанавливает пакет `@anthropic-ai/claude-code` глобально с поддержкой текущего прокси и генерирует изолированный конфиг песочницы со случайными анонимными ID.

---

### Быстрый старт:

1. Скачайте архив со страницы [Releases](https://github.com/timofejmihee1-cpu/claude-stealth-sandbox/releases) или склонируйте репозиторий:
   ```bash
   git clone https://github.com/timofejmihee1-cpu/claude-stealth-sandbox.git
   cd claude-stealth-sandbox
   ```
2. Включите ваш VPN / прокси (например, Happ, Xray, Nekoray) с зарубежным сервером.
3. Запустите **`start.bat`**.
4. В меню выберите:
   * `[8]` или `[9]` — если нужно установить Claude Desktop или CLI в один клик;
   * `[4]` — проверить статус подключения, внешний IP и Kill-Switch;
   * `[1]` или `[2]` — запустить Claude Desktop;
   * `[3]` — запустить Claude Code CLI.

---

<a name="english"></a>
## English Description

**Claude Stealth Sandbox** is an interactive control suite and hardened sandbox for **Claude Desktop** and **Claude Code (CLI)** on Windows. It isolates Claude processes from your host OS, blocks WebRTC IP leaks, spoofs device fingerprints, automates clean installation, and eliminates lingering "Suspended / In Pause" background processes.

### Key Features:

* **Interactive Control Hub (`start.bat`):** Clean ASCII menu for regular & elevated launches, VPN testing, emergency cache clearing, one-click automated installation, and desktop shortcut generation.
* **Strict Kill-Switch:** Probes local proxy inbounds (ports `10808`, `10809`, `2080`, `7890`) and validates external IP check before startup. Prevents running if the proxy is down or returning a blacklisted/blocked country IP.
* **WebRTC & Telemetry Hardening:** Drops non-proxied UDP (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`, `--enforce-webrtc-ip-permission-check`), disables crash reporters, error collectors, and GrowthBook telemetry.
* **Fingerprint Anonymization:** Spoofs device identifier to `MacBook-Air`, timezone to `Europe/Berlin`, locale to `en-US`, and generates randomized persistent 64-character UUIDs.
* **Anti-Zombie Process Watchdog:** Windows 10/11 MSIX lifecycle often freezes closed Electron apps into a "Suspended" state with lingering `chrome-native-host.exe` processes. This sandbox disables UWP suspension in the registry and employs a hidden background watchdog that terminates all tree processes immediately when the console window is closed.
* **One-Click Pre-Hardened Installation:**
  - **[8] Install Claude Desktop:** Automatically installs official Claude Desktop via `winget` or direct download, disables UWP background suspension, disables `CoworkVMService`, strips registry autorun, configures spoofed profile, and creates a desktop shortcut.
  - **[9] Install Claude Code CLI:** Installs Node.js LTS (if needed), globally installs `@anthropic-ai/claude-code` via npm routing through active proxy, and seeds randomized anonymous IDs in `data/cli-profile`.
* **Dual Privilege Support:** Standard user sandbox by default; auto-elevates to High Integrity token with `--dangerously-skip-permissions` when launched via *Run as Administrator*.

### File Structure:

| File | Purpose |
|---|---|
| `start.bat` | Interactive Control Hub (Main Entrypoint) |
| `menu.ps1` | Interactive dashboard logic with IP check, installation & tools |
| `start-claude-desktop.bat` | Direct launcher for Claude Desktop |
| `start-claude-code.bat` | Direct launcher for Claude Code CLI |
| `run-claude-desktop.ps1` | PowerShell core engine for Claude Desktop |
| `run-claude-safe.ps1` | PowerShell core engine for Claude Code |
| `claude-watchdog.ps1` | Hidden background process supervisor |
| `test-browser-leaks.bat` | WebRTC and IP leak verification tool |
| `icon.ico` | Claude Desktop official tray icon asset |

---

### License
MIT License. Free for personal and educational use.
