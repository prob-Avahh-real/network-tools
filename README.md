# Network Tools

Network optimization and VPS deployment tools — shell scripts and documentation for building a secure network infrastructure.

## Contents

### Scripts
- `earth-village-network-optimizer.sh` — Network optimization setup script
- `hysteria2-vps-deploy.sh` — Hysteria2 VPS deployment
- `install-clients-and-clean.sh` — Client installation and cleanup

### Reports & Docs
- `地球村网络优化报告.html` — HTML network optimization report (Chinese)
- `地球村网络优化报告.md` — Markdown version of the report
- `VPS部署方案.md` — VPS deployment guide (Chinese)

## Tech Stack

- **Language:** Bash/Shell
- **Tooling:** ShellCheck, Hysteria2
- **Reports:** HTML + Markdown

## Development

```bash
# Validate files
node scripts/validate.js

# Shell syntax check
bash -n earth-village-network-optimizer.sh
bash -n hysteria2-vps-deploy.sh
bash -n install-clients-and-clean.sh

# ShellCheck lint
shellcheck *.sh
```
