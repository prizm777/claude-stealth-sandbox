# Claude Stealth Sandbox for Windows 🛡️

[English](#english) | [Русский](#русский)

---

<a name="русский"></a>
## 🇷🇺 Описание на русском

**Claude Stealth Sandbox** — это готовое окружение и система запуска для **Claude Desktop** и **Claude Code (CLI)** на Windows, которая полностью изолирует процессы Claude, защищает от геоблокировок Anthropic, блокирует утечки WebRTC и решает проблему зависания процессов в памяти.

### 🔥 Ключевые возможности:

1. **Аппаратный Kill Switch:**
   - Перед каждым запуском проверяет доступность локального Proxy/VPN (Happ, Xray, Sing-box, V2Ray на портах `10808`, `10809`, `2080`, `7890`).
   - Делает контрольный запрос к внешнему API проверки IP: если возвращается IP из РФ или прокси недоступен — **запуск немедленно блокируется**, чтобы не подставить ваш аккаунт под бан.
2. **Защита от утечек WebRTC и телеметрии:**
   - Принудительно отключает непроксированный UDP (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`).
   - Запрещает краш-репорты, отчёты об ошибках и телеметрию Anthropic (`DISABLE_TELEMETRY=1`, `DO_NOT_TRACK=1`, `--disable-breakpad`).
3. **Спуфинг окружения и фингерпринта:**
   - Подменяет имя компьютера на `MacBook-Air`.
   - Подменяет часовой пояс на `Europe/Berlin`, локаль на `en-US`.
   - Генерирует уникальные случайные `machineID` и `userID`.
   - Изолирует профили данных внутри локальной папки `data/` — Claude никогда не читает ваш реальный системный `%USERPROFILE%` или `%APPDATA%`.
4. **Решение бага «В режиме паузы» (Anti-Zombie Watchdog):**
   - В Windows 10/11 приложения UWP/MSIX (включая Claude Desktop) при закрытии часто зависают в диспетчере задач в статусе **«Приостановлено» (Suspended)** и держат в памяти сотни мегабайт и фоновые процессы `chrome-native-host.exe`.
   - Sandbox автоматически отключает фоновое зависание в реестре Windows.
   - В фоне работает скрытый независимый **Watchdog-сторож**: при закрытии окна запуска крестиком он за 10 мс подчистую выгружает все связанные процессы Claude из памяти (0 висячих процессов в Диспетчере задач).
5. **Двойной режим (Обычный / Администратор):**
   - **Обычный запуск:** Безопасный стандартный режим песочницы.
   - **Запуск от имени администратора:** Если запустить батник от админа, Claude получает повышенный токен целостности (High Integrity / RunAs), а для Claude Code CLI автоматически включается `--dangerously-skip-permissions`. Это позволяет Claude писать в любые консоли, завершать зависшие процессы (`taskkill`) и управлять службами Windows без лишних подтверждений.

---

### 🚀 Быстрый старт:

1. Склонируйте репозиторий:
   ```bash
   git clone https://github.com/YOUR_USERNAME/claude-stealth-sandbox.git
   cd claude-stealth-sandbox
   ```
2. Включите ваш VPN / прокси-клиент (например, Happ, Xray или Nekoray) с зарубежным сервером.
3. Запуск:
   * **Claude Desktop:** дважды кликните по `start-claude-desktop.bat` (или ПКМ $\rightarrow$ *Запуск от имени администратора*).
   * **Claude Code (CLI):** дважды кликните по `start-claude-code.bat` (или запускайте из терминала с вашими аргументами).
4. Проверка на утечки:
   * Запустите `test-browser-leaks.bat` для автоматического теста WebRTC и IP на `browserleaks.com`.

---

<a name="english"></a>
## 🇬🇧 English Description

**Claude Stealth Sandbox** is a turnkey launcher and sandbox suite for **Claude Desktop** and **Claude Code (CLI)** on Windows. It isolates Claude processes from your host OS, blocks WebRTC IP leaks, spoofs device fingerprints, and eliminates lingering "Suspended / In Pause" background processes.

### 🌟 Key Features:

* **Strict Kill-Switch:** Probes local proxy inbounds (ports `10808`, `10809`, `2080`, `7890`) and queries external IP check before startup. Prevents running if the proxy is down or returning a blacklisted/blocked country IP.
* **WebRTC & Telemetry Hardening:** Drops non-proxied UDP (`--force-webrtc-ip-handling-policy=disable_non_proxied_udp`), disables crash-reporters, error collectors, and GrowthBook telemetry.
* **Fingerprint Anonymization:** Spoofs device identifier to `MacBook-Air`, timezone to `Europe/Berlin`, locale to `en-US`, and generates randomized persistent UUIDs.
* **Anti-Zombie Process Watchdog:** Windows 10/11 MSIX lifecycle often freezes closed Electron apps into a "Suspended" state with lingering `chrome-native-host.exe` processes. This sandbox disables UWP suspension in the registry and employs a hidden background watchdog that terminates all tree processes immediately when the console window is closed.
* **Dual Privilege Support:** Standard user sandbox by default; auto-elevates to High Integrity token with `--dangerously-skip-permissions` when launched via *Run as Administrator*.

### 📂 File Structure:

| File | Purpose |
|---|---|
| `start-claude-desktop.bat` | One-click launcher for Claude Desktop |
| `start-claude-code.bat` | One-click launcher for Claude Code CLI |
| `run-claude-desktop.ps1` | PowerShell core engine for Claude Desktop |
| `run-claude-safe.ps1` | PowerShell core engine for Claude Code |
| `claude-watchdog.ps1` | Hidden background process supervisor |
| `test-browser-leaks.bat` | WebRTC and IP leak verification tool |

---

### 📄 License
MIT License. Free for personal and commercial use.
