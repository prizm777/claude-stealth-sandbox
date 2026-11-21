# Claude Stealth Sandbox for Windows

[English](#english) | [Русский](#русский)

---

<a name="русский"></a>
## Описание на русском

**Claude Stealth Sandbox** — это готовое окружение и интерактивный хаб для безопасной работы с **Claude Desktop** и **Claude Code (CLI)** на Windows. Sandbox полностью изолирует процессы Claude, защищает аккаунт от геоблокировок Anthropic, поддерживает как локальные Proxy, так и системные VPN (TUN/WireGuard/Outline), динамически синхронизирует часовой пояс, блокирует утечки WebRTC, подменяет фингерпринт устройства, умно импортирует существующие сессии и решает проблему зависания процессов в памяти Windows.

![Release](https://img.shields.io/badge/Release-v1.4.0-blue?style=for-the-badge)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue?style=for-the-badge&logo=windows)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Security](https://img.shields.io/badge/Security-Kill--Switch%20Active-brightgreen?style=for-the-badge)

> [!WARNING]
> **Статус проекта: Публичное тестирование (Community Beta ~50/50)**
> Эта версия песочницы только что вышла и активно тестируется в боевых условиях. Из-за огромного разнообразия версий Windows 10/11, VPN-протоколов (Amnezia, Outline, WireGuard, V2Ray, Clash, Happ) и провайдеров возможны непредвиденные системные баги или шероховатости.
> Если вы наткнулись на ошибку, вылет или странное поведение — пожалуйста, **[создайте Issue на GitHub](https://github.com/timofejmihee1-cpu/claude-stealth-sandbox/issues)**, и мы оперативно выпустим фикс!

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

1. **Универсальный Kill-Switch (Proxy + Системный VPN/TUN):**
   * **Режим Proxy (Happ, Xray, Nekoray, Clash, V2RayN):** Трафик принудительно направляется через локальный порт (`10808`, `10809`, `2080`, `7890` или `$env:CLAUDE_PROXY_PORT`). Если прокси выключится во время работы — в Claude просто пропадет интернет (`ERR_PROXY_CONNECTION_FAILED`), а реальный IP физически не сможет утечь в сеть!
   * **Режим Системного VPN (Amnezia, Outline, WireGuard, OpenVPN):** Если локальные порты не используются, скрипт автоматически определяет системный VPN через виртуальный адаптер (TUN/TAP).
   * **Live Watchdog Kill-Switch:** Фоновый сторож каждые 4 секунды опрашивает сеть. Если в режиме TUN VPN внезапно отключится и IP станет российским — сторож моментально «убивает» процесс Claude, предотвращая бан!
   * **Блокируемые регионы:** Запуск прерывается при IP из `RU`, `BY`, `IR`, `KP`, `CU`, `SY`.
2. **Динамическая синхронизация часового пояса (Zero Timezone Mismatch):**
   * Антифрод-системы отслеживают разницу между IP сервера и часами системы (Timezone Mismatch).
   * Sandbox на лету считывает точный часовой пояс сервера выхода (`$check.timezone`, например `Europe/Helsinki`, `America/New_York`, `Europe/Amsterdam`) и выставляет его в `$env:TZ`.
3. **Smart Detection & 1-Click Migration (Умный перенос профилей):**
   * Никакой паники от чистого экрана! При первом запуске песочница проверяет, есть ли на компьютере уже авторизованный аккаунт в Windows.
   * **Claude Desktop:** если найден залогиненный аккаунт в Windows, песочница предлагает в 1 клик (Enter) скопировать авторизацию и куки в защищенную папку `data/desktop-profile`. Вы сразу остаетесь залогинены в своем аккаунте.
   * **Claude Code CLI:** если в Windows есть существующие проекты и сессии, песочница переносит их, и команда `/resume` сразу видит все ваши диалоги.
4. **Динамический выбор виртуального диска (No Conflicts):**
   * Вместо жестко зашитого диска `X:`, скрипт проверяет свободные буквы (`X`, `Y`, `Z`, `W`, `V`, `U`, `T`) и никогда не конфликтует с существующими флешками, SSD или сетевыми дисками.
5. **Защита от утечек WebRTC и телеметрии:**
   * Принудительно отключает непроксированный UDP в Chromium (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp` для Proxy / `default_public_interface_only` для TUN).
   * Запрещает сбор телеметрии, краш-дампы и метрики Anthropic (`DISABLE_TELEMETRY=1`, `DO_NOT_TRACK=1`, `DISABLE_GROWTHBOOK=1`, `--disable-breakpad`, `--disable-crash-reporter`).
6. **Спуфинг окружения и фингерпринта:**
   * Подменяет имя компьютера на `MacBook-Air`, локаль на `en-US`.
   * Генерирует уникальные случайные 64-символьные `machineID` и `userID`.
   * Изолирует данные профиля в папке `data/` — Claude никогда не читает системный `%USERPROFILE%`.
7. **Решение бага «В режиме паузы» и очистка краш-блокировок:**
   * Отключает фоновое зависание в реестре Windows (`BackgroundAccessApplications\Claude_pzs8sxrjxfjjc`).
   * В фоне работает независимый Watchdog-сторож: при закрытии консоли он подчистую выгружает все связанные процессы Claude из памяти (0 висячих процессов в Диспетчере задач).
   * Автоматически подчищает висячие артефакты сбоев Chromium (`SingletonLock`, `SingletonSocket`, `SingletonCookie`, `lockfile`).

---

### Быстрый старт:

1. Скачайте архив со страницы [Releases](https://github.com/timofejmihee1-cpu/claude-stealth-sandbox/releases) или склонируйте репозиторий:
   ```bash
   git clone https://github.com/timofejmihee1-cpu/claude-stealth-sandbox.git
   cd claude-stealth-sandbox
   ```
2. Включите ваш VPN (Amnezia, Outline, WireGuard) или Proxy (Happ, Xray, Nekoray) с зарубежным сервером.
3. Запустите **`start.bat`**.
4. В меню выберите:
   * `[8]` или `[9]` — если нужно установить Claude Desktop или CLI в один клик;
   * `[4]` — проверить статус подключения, режим (Proxy/TUN), страну, IP и Kill-Switch;
   * `[1]` или `[2]` — запустить Claude Desktop;
   * `[3]` — запустить Claude Code CLI.

---

<a name="english"></a>
## English Description

**Claude Stealth Sandbox** is an interactive control suite and hardened sandbox for **Claude Desktop** and **Claude Code (CLI)** on Windows. It isolates Claude processes from your host OS, eliminates WebRTC IP leaks, supports both Local Proxies and System VPNs (TUN/WireGuard/Outline), dynamically synchronizes timezone with your exit node, spoofs device fingerprints, smartly migrates existing logins, and eliminates lingering "Suspended / In Pause" background processes.

> [!WARNING]
> **Project Status: Public Community Beta (~50/50 Testing)**
> This is a newly released version under active real-world community testing. Due to the wide diversity of Windows 10/11 builds, VPN/proxy stacks (Amnezia, Outline, WireGuard, V2Ray, Clash, Sing-box), and ISP routing, unexpected edge-case bugs may occur.
> If you encounter any bugs, crashes, or glitches, please **[open an Issue on GitHub](https://github.com/timofejmihee1-cpu/claude-stealth-sandbox/issues)** so we can patch it immediately!

### Key Features:

* **Dual-Mode Kill-Switch (Proxy & System TUN):**
  - **Local Proxy Mode:** Inbounds on ports `10808`, `10809`, `2080`, `7890`. If proxy terminates during operation, Chromium drops to `ERR_PROXY_CONNECTION_FAILED`, making IP leaks impossible.
  - **System VPN / TUN Mode (Amnezia, Outline, WireGuard):** Auto-detected when no local inbounds exist.
  - **Active Live Watchdog:** Background supervisor polls IP every 4 seconds. If VPN drops and IP reverts to sanctioned regions (`RU`, `BY`, `IR`, `KP`, `CU`, `SY`), Watchdog immediately kills all Claude processes.
* **Dynamic Timezone Alignment:** Prevents anti-fraud flags caused by Timezone Mismatches. Automatically parses exit node timezone (`$check.timezone`, e.g. `Europe/Helsinki`, `America/New_York`) and binds it to `$env:TZ`.
* **Smart Detection & 1-Click Profile Migration:** No blank profile panics! Automatically detects existing Windows installations of Claude Desktop (`Claude-Data`) and Claude Code CLI (`~/.claude/projects`), offering to clone authentication tokens, cookies, and chat history into the hardened `data/` directory.
* **Dynamic Virtual Drive Letter:** Automatically scans for available drive letters (`X`, `Y`, `Z`, `W`, etc.) to prevent collisions with physical drives.
* **WebRTC & Telemetry Hardening:** Drops non-proxied UDP (`disable_non_proxied_udp` / `default_public_interface_only`), disables crash reporters, error collectors, and GrowthBook telemetry.
* **Fingerprint Anonymization:** Spoofs device identifier to `MacBook-Air`, locale to `en-US`, and generates randomized persistent 64-character UUIDs.
* **Anti-Zombie Process Watchdog & Singleton Lock Cleanup:** Eliminates Windows 10/11 MSIX lifecycle "Suspended" state leaks and automatically clears stale `SingletonLock` artifacts.

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
