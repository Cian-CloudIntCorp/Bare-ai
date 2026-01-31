# Bare-AI: Enterprise Self-Healing Mesh

**Bare-AI** is a hierarchical multi-agent system designed to autonomously monitor, diagnose, and repair distributed infrastructure. It implements a **Supervisor-Worker** architecture over a Zero-Trust Tailscale mesh, enabling centralized intelligence with decentralized execution.

## 📂 Repository Structure

| File | Version | Role | Description |
| :--- | :--- | :--- | :--- |
| **`setup_bare-ai-brain.sh`** | `v003` | **Supervisor** | The Central Brain. Harvests JSON summaries via SSH, aggregates fleet intelligence, and synthesizes global operational strategies. |
| **`setup_bare-ai-worker.sh`** | `v002` | **Worker** | The Linux Specialist. Runs on RKE, Vault, and Tailscale nodes. Handles local self-healing and generates daily logs. |
| **`setup_bare-ai-win.ps1`** | `Exp` | **Worker** | *Experimental* PowerShell wrapper for Windows nodes. Adapts self-healing logic for Windows Server environments. |


---

Security & Requirements
Tailscale: Must be installed and connected on all nodes.

SSH Identity: The Brain uses SSH keys for passwordless access. Ensure ssh-copy-id or Tailscale ACLs are configured.

Gemini API: All nodes require a valid GEMINI_API_KEY in their environment variables.

---

## 🚀 Quick Start (Linux)

### 1. Deploy the Brain (Supervisor)
Run this on your secure host machine (Admin workstation or dedicated VM).

```bash
# 1. Download and run the v003 setup
curl -O [https://raw.githubusercontent.com/Cian-CloudIntCorp/bare-ai-brain/main/setup_bare-ai-brain.sh](https://raw.githubusercontent.com/Cian-CloudIntCorp/bare-ai-brain/main/setup_bare-ai-brain.sh)
chmod +x setup_bare-ai-brain.sh
./setup_bare-ai-brain.sh

# 2. Add your workers to the fleet configuration
nano ~/.bare-ai/brain/fleet.conf
# Add one Tailscale hostname per line, e.g.:
# rke-node-01
# vault-manager



