<div align="center">

[![GitHub Stars](https://img.shields.io/github/stars/Win-Net/dnstt-DNS-changer?style=for-the-badge&color=00d2ff)](https://github.com/Win-Net/dnstt-DNS-changer)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-blue?style=for-the-badge)]()

**[English](#english)** | **[فارسی](#فارسی)**

</div>

---

<a name="english"></a>
## 🇬🇧 English

### What is this?
DNSTT-DNS-Changer manages multiple DNS servers for your DNSTT tunnel. When one DNS server goes down, it automatically switches to the next one.

### Features
- 🔄 **Auto Failover** — Switches DNS automatically when current one fails
- 🩺 **Health Monitoring** — Checks connection every 10 seconds
- 📊 **CLI Dashboard** — Beautiful terminal management interface
- ⚙️ **Easy Config** — Simple configuration file
- 🔁 **Round-Robin** — Cycles through all DNS servers
- 📝 **Full Logging** — Complete event logs

### Quick Install

```bash
bash <(curl -sL https://raw.githubusercontent.com/Win-Net/dnstt-DNS-changer/main/install.sh)
