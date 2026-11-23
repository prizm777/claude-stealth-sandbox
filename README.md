# Claude Stealth Sandbox for Windows

<p align="center">
  <img src="icon.ico" width="80" height="80" alt="Claude Stealth Sandbox" /><br>
  <b>Изолированная среда и защитный хаб для Claude Desktop & Claude Code на Windows</b>
</p>

<p align="center">
  <a href="https://github.com/prizm777/claude-stealth-sandbox/releases/tag/v1.6.0"><img src="https://img.shields.io/badge/Release-v1.6.0-blue?style=for-the-badge" alt="Release v1.6.0"></a>
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows 10/11">
  <img src="https://img.shields.io/badge/Security-Socket%20Tripwire%200.2ms-brightgreen?style=for-the-badge" alt="Socket Tripwire">
  <img src="https://img.shields.io/badge/DNS-Cloudflare%20DoH-purple?style=for-the-badge" alt="Cloudflare DoH">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License">
</p>

[English](#english-version) | [Русский](#русская-версия)

---

<a name="русская-версия"></a>
## 🇷🇺 Описание на русском

**Claude Stealth Sandbox** — это автономная среда и защитный хаб для безопасного запуска **Claude Desktop** и **Claude Code (CLI)** на Windows в регионах с ограничениями. 

Песочница полностью изолирует процессы Claude, предотвращает геоблокировки Anthropic, перехватывает утечки IP через аппаратную растяжку сокетов (**Socket Tripwire** ~0.2 мс), отключает непроксированный WebRTC UDP, принудительно шифрует DNS через **Cloudflare DoH**, синхронизирует часовой пояс с VPN/Proxy и сохраняет авторизацию в системный Сейф (**Universal Session Vault**).

> [!TIP]
> **Автономный вход (Zero-Login Loss):** Сессия и куки автоматически сохраняются в системный Сейф (`~/.claude-sandbox-vault`). Обновления файлов и перемещение папок больше никогда не сбрасывают вход в аккаунт!

---

### 🕹️ Интерактивный Центр Управления (`start.bat`)

Запуск через `start.bat` открывает лаконичный и быстрый интерфейс управления:

```text
======================================================================
            CLAUDE STEALTH SANDBOX FOR WINDOWS (v1.6.0)
       WebRTC Hardening, Kill-Switch & Anti-Zombie Watchdog
======================================================================
 [*] Текущие привилегии: Обычный пользователь
----------------------------------------------------------------------
  [1] Запустить Claude Desktop (Безопасная песочница)
  [2] Запустить Claude Code CLI (Терминал песочницы)
  [3] Диагностика сети и проверка утечек (IP, WebRTC, DNS)
  [4] Сейф сессий (Universal Session Vault): бэкап и вход
  [5] Инструменты, ярлыки и установка

  [0] Выход
----------------------------------------------------------------------
  Выберите действие [0-5]:
```

---

### 🚀 Быстрый старт (за 3 шага)

1. **Скачайте готовый архив** со страницы [Releases](https://github.com/prizm777/claude-stealth-sandbox/releases/tag/v1.6.0) и распакуйте в любую папку.
2. **Включите ваш VPN** (Amnezia, Outline, WireGuard) или **Proxy** (Happ, Xray, Nekoray, Clash, V2RayN) с зарубежным сервером.
3. Запустите **`start.bat`**:
   * Выберите `[1]` для запуска Claude Desktop;
   * Или `[2]` для вызова терминала Claude Code CLI.

---

### 🛡️ Технологии защиты и возможности

| Функция | Как это работает |
|---|---|
| ⚡ **Socket Tripwire (~0.2 мс)** | Низкоуровневый перехват через WinAPI (`iphlpapi.dll -> GetExtendedTcpTable`). Если Клод пытается открыть прямое сетевое соединение в обход `127.0.0.1`, сокет перехватывается в зародыше (`SYN_SENT`), а процессы Клода моментально ликвидируются. |
| 🌐 **Универсальный Kill-Switch** | Поддерживает как локальные Proxy (порты `10808`, `10809`, `2080`, `7890`), так и системные VPN (TUN). При обрыве соединения реальный IP физически не попадает в сеть. |
| 🕒 **Zero Timezone Mismatch** | Защита от антифрод-проверок несовпадения времени. Скрипт считывает часовой пояс внешнего сервера выхода (`$check.timezone`) и транслирует его в переменные окружения `$env:TZ`. |
| 🔐 **Universal Session Vault** | Зеркалирование рабочего профиля, токенов и cookies в системный каталог `~/.claude-sandbox-vault`. При скачивании новых версий вход сохраняется навсегда. |
| 🔒 **Cloudflare DoH Shield** | Полное шифрование DNS-запросов через `https://chrome.cloudflare-dns.com/dns-query`, исключающее утечки доменов вашему интернет-провайдеру. |
| 🚫 **WebRTC & Анти-Слежка** | Блокировка непроксированного UDP (`disable_non_proxied_udp`), спуфинг имени ПК на `MacBook-Air`, принудительная локаль `en-US` и подавление телеметрии/краш-дампов. |
| 🧹 **Supervisor Mode** | Лаунчер отслеживает жизненный цикл процессов. При закрытии окна Claude или консоли все связанные процессы выгружаются подчистую — ноль зависших зомби в Диспетчере задач. |

---

<a name="english-version"></a>
## 🇬🇧 English Version

**Claude Stealth Sandbox** is a lightweight, hardened isolation suite and interactive control hub for **Claude Desktop** and **Claude Code (CLI)** on Windows. 

It isolates Claude execution environments, prevents geoblocking restrictions, intercepts raw socket leaks via low-level **Kernel Socket Tripwire** (~0.2ms latency), mitigates WebRTC UDP exposure, enforces encrypted **Cloudflare DNS-over-HTTPS (DoH)**, aligns timezones dynamically, and guarantees persistent logins via the **Universal Session Vault**.

---

### 🚀 Quick Start

1. Download the latest release archive from [Releases](https://github.com/prizm777/claude-stealth-sandbox/releases/tag/v1.6.0).
2. Connect your Proxy (Happ, Xray, Nekoray, Clash) or System VPN (Amnezia, Outline, WireGuard).
3. Run **`start.bat`** and select:
   * `[1]` to launch Claude Desktop in sandbox;
   * `[2]` to start Claude Code CLI terminal;
   * `[3]` for network & WebRTC diagnostics.

---

### 🛡️ Security Architecture

* **Kernel-level Socket Tripwire (~0.2ms latency):** Direct Windows TCP table inspection via WinAPI (`iphlpapi.dll -> GetExtendedTcpTable`). If any Claude process attempts an outbound socket connection bypassing `127.0.0.1`, it is intercepted at `SYN_SENT` state and killed immediately.
* **Dual-Engine Kill-Switch:** Seamlessly operates with local SOCKS5/HTTP proxies (`10808`, `10809`, `2080`, `7890`) and system TUN adapters with auto-failover and IP sanity validation.
* **Dynamic Timezone Alignment:** Prevents timezone-fingerprint mismatch flags by resolving exit node timezone and injecting `$env:TZ`.
* **Universal Session Vault:** Encrypted session, cookie, and OAuth credential mirroring at `~/.claude-sandbox-vault`. Updating versions never resets your authentication.
* **Encrypted DNS Shield:** Hardened DoH via Cloudflare (`https://chrome.cloudflare-dns.com/dns-query`) blocks ISP DNS inspection.
* **Supervisor Process Management:** Clean exit hooks guarantee zero zombie or suspended Electron/Chromium background processes.

---

### 📁 Репозиторий / Repository Structure

```text
├── start.bat                  # Главная точка входа (Interactive Control Hub)
├── menu.ps1                   # Логика интерактивного меню и диагностика
├── start-claude-desktop.bat   # Прямой запуск Claude Desktop
├── start-claude-code.bat      # Прямой запуск Claude Code CLI
├── run-claude-desktop.ps1     # Движок изоляции Claude Desktop
├── run-claude-safe.ps1        # Движок изоляции Claude Code CLI
├── claude-watchdog.ps1        # Фоновый сторож, Kill-Switch и Socket Tripwire
├── test-browser-leaks.bat     # Онлайн-тест WebRTC и DNS утечек
└── icon.ico                   # Иконка приложения
```

---

### License
MIT License. Free for open community, educational, and personal use.
