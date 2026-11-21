# Claude Stealth Sandbox for Windows

[English](#english) | [Русский](#русский)

---

<a name="русский"></a>
## Описание на русском

**Claude Stealth Sandbox** — это готовое окружение и интерактивный хаб для безопасной работы с **Claude Desktop** и **Claude Code (CLI)** на Windows. Sandbox полностью изолирует процессы Claude, защищает аккаунт от геоблокировок Anthropic, динамически синхронизирует часовой пояс с VPN-выходом, блокирует утечки WebRTC, подменяет фингерпринт устройства, умно импортирует существующие сессии и решает проблему зависания процессов в памяти Windows.

![Release](https://img.shields.io/badge/Release-v1.3.0-blue?style=for-the-badge)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue?style=for-the-badge&logo=windows)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Security](https://img.shields.io/badge/Security-Kill--Switch%20Active-brightgreen?style=for-the-badge)

---

### Интерактивное Меню Управления (`start.bat`):

При запуске главного файла `start.bat` открывается удобное интерактивное меню:

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

1. **Аппаратный Kill Switch и расширенный гео-блок:**
   - Автоматически находит активный порт Proxy/VPN (Happ, Xray, Sing-box, V2Ray, Clash на портах `10808`, `10809`, `2080`, `7890` или `$env:CLAUDE_PROXY_PORT`).
   - Перед каждым запуском проверяет IP через внешний API: если прокси отключен или возвращает IP из стран под санкциями (`RU`, `BY`, `IR`, `KP`, `CU`, `SY`) — **запуск немедленно блокируется**, предотвращая бан аккаунта.
2. **Динамическая синхронизация часового пояса (Zero Timezone Mismatch):**
   - Большинство антифрод-систем банят за несоответствие часового пояса и IP (например, когда IP финский или американский, а система рапортует локальное время).
   - Sandbox на лету считывает точный часовой пояс сервера выхода (`$check.timezone`, например `Europe/Helsinki`, `America/New_York`, `Europe/Amsterdam`) и принудительно выставляет его в переменную `$env:TZ`.
3. **Smart Detection & 1-Click Migration (Умный перенос профилей):**
   - Никакой паники от чистого экрана! При первом запуске песочница проверяет, есть ли на этом компьютере уже авторизованный аккаунт в Windows.
   - **Claude Desktop:** если найден залогиненный аккаунт в Windows, песочница предлагает в 1 клик (Enter) скопировать авторизацию и куки в защищенную изолированную папку `data/desktop-profile`. Вы сразу остаетесь залогинены в своем аккаунте со всеми подписками.
   - **Claude Code CLI:** если в Windows есть существующие проекты и история сессий, песочница предлагает перенести их, и команда `/resume` сразу отображает все ваши диалоги.
4. **Защита от утечек WebRTC и телеметрии:**
   - Принудительно отключает непроксированный UDP в Chromium (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`, `--enforce-webrtc-ip-permission-check`).
   - Запрещает сбор телеметрии, краш-дампы и трекинг Anthropic (`DISABLE_TELEMETRY=1`, `DO_NOT_TRACK=1`, `DISABLE_GROWTHBOOK=1`, `--disable-breakpad`, `--disable-crash-reporter`).
5. **Спуфинг окружения и фингерпринта:**
   - Подменяет имя компьютера на `MacBook-Air`, локаль на `en-US`.
   - Генерирует уникальные случайные 64-символьные `machineID` и `userID`.
   - Изолирует профиль в папке `data/` — Claude никогда не читает системный `%USERPROFILE%`.
6. **Решение бага «В режиме паузы» (Anti-Zombie Watchdog):**
   - В Windows 10/11 приложения UWP/MSIX при закрытии окна сворачиваются в фоновые процессы со статусом **«Приостановлено» (Suspended)** и держат память и сопутствующие процессы `chrome-native-host.exe`.
   - Sandbox отключает фоновое зависание в реестре Windows (`BackgroundAccessApplications\Claude_pzs8sxrjxfjjc`).
   - В фоне работает скрытый независимый **Watchdog-сторож**: при закрытии окна консоли он подчистую выгружает все связанные процессы Claude из памяти (0 висячих процессов в Диспетчере задач).
7. **Двойной режим (Обычный / Администратор):**
   - **Обычный запуск:** Безопасный стандартный режим песочницы.
   - **Запуск от имени администратора:** Claude получает токен высокой целостности (High Integrity / RunAs), а для Claude Code CLI автоматически включается `--dangerously-skip-permissions`.

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
   * `[4]` — проверить статус подключения, страну, внешний IP, таймзону и Kill-Switch;
   * `[1]` или `[2]` — запустить Claude Desktop;
   * `[3]` — запустить Claude Code CLI.

---

<a name="english"></a>
## English Description

**Claude Stealth Sandbox** is an interactive control suite and hardened sandbox for **Claude Desktop** and **Claude Code (CLI)** on Windows. It isolates Claude processes from your host OS, eliminates WebRTC IP leaks, dynamically synchronizes timezone with your VPN exit node, spoofs device fingerprints, smartly migrates existing logins, and eliminates lingering "Suspended / In Pause" background processes.

### Key Features:

* **Strict Kill-Switch & Extended Geo-Enforcement:** Probes local proxy ports (`10808`, `10809`, `2080`, `7890`) and validates external IP before startup. Immediately terminates launch if the proxy is down or returns an IP from sanctioned regions (`RU`, `BY`, `IR`, `KP`, `CU`, `SY`).
* **Dynamic Timezone Alignment:** Prevents anti-fraud flags caused by Timezone Mismatches. Automatically parses exit node timezone (`$check.timezone`, e.g. `Europe/Helsinki`, `America/New_York`) and binds it to `$env:TZ`.
* **Smart Detection & 1-Click Profile Migration:** No blank profile panics! Automatically detects existing Windows installations of Claude Desktop and Claude Code CLI, offering to clone authentication tokens, cookies, and chat history into the hardened `data/` directory.
* **WebRTC & Telemetry Hardening:** Drops non-proxied UDP (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`), disables crash reporters, error collectors, and GrowthBook telemetry.
* **Fingerprint Anonymization:** Spoofs device identifier to `MacBook-Air`, locale to `en-US`, and generates randomized persistent 64-character UUIDs.
* **Anti-Zombie Process Watchdog:** Eliminates Windows 10/11 MSIX lifecycle "Suspended" state leaks with automated registry tuning and a background watchdog supervisor.
* **1-Click Pre-Hardened Setup:** Built-in automated installers for Claude Desktop (`Anthropic.Claude`) and Claude Code CLI (`@anthropic-ai/claude-code`).

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
