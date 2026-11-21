# Claude Stealth Sandbox for Windows 🛡️

[English](#english) | [Русский](#русский)

---

<a name="русский"></a>
## 🇷🇺 Описание на русском

**Claude Stealth Sandbox** — это готовое окружение и интерактивный хаб для безопасной работы с **Claude Desktop** и **Claude Code (CLI)** на Windows. Sandbox полностью изолирует процессы Claude, защищает аккаунт от геоблокировок Anthropic, блокирует утечки WebRTC, подменяет фингерпринт устройства и решает проблему зависания процессов в памяти Windows.

![Interface Preview](https://img.shields.io/badge/Windows-10%20%7C%2011-blue?style=for-the-badge&logo=windows)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Security-Kill--Switch%20Active-brightgreen?style=for-the-badge)

---

### 🔥 Интерактивное Меню Управления (`start.bat`):

При запуске главного файла `start.bat` открывается удобное интерактивное меню:

```text
======================================================================
             🛡️  CLAUDE STEALTH SANDBOX FOR WINDOWS  🛡️
      Anti-Ban, WebRTC Hardening, Kill-Switch & Anti-Zombie Watchdog
======================================================================
  [1] 🚀 Запустить Claude Desktop (Безопасная песочница)
  [2] ⚡ Запустить Claude Desktop от имени Администратора (UAC)
  [3] 💻 Запустить Claude Code CLI (Терминал песочницы)
  [4] 🌐 Проверить статус Proxy / VPN и Kill-Switch
  [5] 🧪 Проверить защиту от утечек WebRTC и IP в браузере
  [6] 🧹 Экстренная очистка (выгрузить все процессы и кэш)
  [7] 📌 Создать ярлык на Рабочем столе

  [0] ❌ Выход
======================================================================
```

---

### 🛡️ Ключевые возможности:

1. **Аппаратный Kill Switch:**
   - Автоматически находит активный порт Proxy/VPN (Happ, Xray, Sing-box, V2Ray, Clash на портах `10808`, `10809`, `2080`, `7890`).
   - Перед каждым запуском делает проверочный запрос к внешнему API: если возвращается IP из РФ или прокси отключился — **запуск немедленно блокируется**, чтобы не подставить ваш аккаунт под бан.
2. **Защита от утечек WebRTC и телеметрии:**
   - Принудительно отключает непроксированный UDP (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`).
   - Запрещает сбор телеметрии, краш-дампы и метрики Anthropic (`DISABLE_TELEMETRY=1`, `DO_NOT_TRACK=1`, `--disable-breakpad`, `--disable-crash-reporter`).
3. **Спуфинг окружения и фингерпринта:**
   - Подменяет имя компьютера на `MacBook-Air`.
   - Подменяет часовой пояс на `Europe/Berlin`, локаль на `en-US`.
   - Генерирует уникальные случайные `machineID` и `userID`.
   - Изолирует данные профиля в папке `data/` — Claude никогда не читает ваш реальный системный `%USERPROFILE%` или `%APPDATA%`.
4. **Решение бага «В режиме паузы» (Anti-Zombie Watchdog):**
   - В Windows 10/11 приложения UWP/MSIX (включая Claude Desktop) при закрытии окна сворачиваются в фоновые процессы со статусом **«Приостановлено» (Suspended)** и держат память и сопутствующие процессы `chrome-native-host.exe`.
   - Sandbox автоматически отключает фоновое зависание в реестре Windows.
   - В фоне работает скрытый независимый **Watchdog-сторож**: при закрытии окна консоли крестиком он за миллисекунды подчистую выгружает все связанные процессы Claude из памяти (0 висячих процессов в Диспетчере задач).
5. **Двойной режим (Обычный / Администратор):**
   - **Обычный запуск:** Безопасный стандартный режим песочницы.
   - **Запуск от имени администратора:** Claude получает токен высокой целостности (High Integrity / RunAs), а для Claude Code CLI автоматически включается `--dangerously-skip-permissions`. Это позволяет Claude писать в любые консоли, завершать зависшие процессы (`taskkill`) и управлять службами Windows без лишних подтверждений.

---

### 🚀 Быстрый старт:

1. Скачайте готовый архив из [Releases](https://github.com/timofejmihee1-cpu/claude-stealth-sandbox/releases) или склонируйте репозиторий:
   ```bash
   git clone https://github.com/timofejmihee1-cpu/claude-stealth-sandbox.git
   cd claude-stealth-sandbox
   ```
2. Включите ваш VPN / прокси (например, Happ, Xray, Nekoray) с зарубежным сервером.
3. Запустите **`start.bat`**.
4. В меню выберите:
   * `[1]` или `[2]` — для запуска Claude Desktop;
   * `[3]` — для работы с Claude Code CLI;
   * `[4]` — чтобы перед запуском убедиться, что ваш IP и Kill-Switch в порядке.

---

<a name="english"></a>
## 🇬🇧 English Description

**Claude Stealth Sandbox** is an interactive control suite and hardened sandbox for **Claude Desktop** and **Claude Code (CLI)** on Windows. It isolates Claude processes from your host OS, blocks WebRTC IP leaks, spoofs device fingerprints, and eliminates lingering "Suspended / In Pause" background processes.

### 🌟 Key Features:

* **Interactive Control Hub (`start.bat`):** Unified menu for regular & elevated launches, VPN testing, emergency cache clearing, and desktop shortcut generation.
* **Strict Kill-Switch:** Probes local proxy inbounds (ports `10808`, `10809`, `2080`, `7890`) and queries external IP check before startup. Prevents running if the proxy is down or returning a blacklisted/blocked country IP.
* **WebRTC & Telemetry Hardening:** Drops non-proxied UDP (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`), disables crash-reporters, error collectors, and GrowthBook telemetry.
* **Fingerprint Anonymization:** Spoofs device identifier to `MacBook-Air`, timezone to `Europe/Berlin`, locale to `en-US`, and generates randomized persistent UUIDs.
* **Anti-Zombie Process Watchdog:** Windows 10/11 MSIX lifecycle often freezes closed Electron apps into a "Suspended" state with lingering `chrome-native-host.exe` processes. This sandbox disables UWP suspension in the registry and employs a hidden background watchdog that terminates all tree processes immediately when the console window is closed.
* **Dual Privilege Support:** Standard user sandbox by default; auto-elevates to High Integrity token with `--dangerously-skip-permissions` when launched via *Run as Administrator*.

### 📂 File Structure:

| File | Purpose |
|---|---|
| `start.bat` | 🌟 Interactive Control Hub (Main Entrypoint) |
| `menu.ps1` | Interactive dashboard logic with IP check & tools |
| `start-claude-desktop.bat` | Direct launcher for Claude Desktop |
| `start-claude-code.bat` | Direct launcher for Claude Code CLI |
| `run-claude-desktop.ps1` | PowerShell core engine for Claude Desktop |
| `run-claude-safe.ps1` | PowerShell core engine for Claude Code |
| `claude-watchdog.ps1` | Hidden background process supervisor |
| `test-browser-leaks.bat` | WebRTC and IP leak verification tool |

---

### 📄 License
MIT License. Free for personal and educational use.
