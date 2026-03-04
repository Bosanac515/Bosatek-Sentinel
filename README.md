# 🛡️ BosaTek Sentinel V3.8
**Tactical Reconnaissance Framework & AI Offensive Assistant**

BosaTek Sentinel is a specialized automation framework designed to streamline the initial phases of a penetration test. It orchestrates industry-standard recon tools within a structured tmux environment, integrating a custom-tuned Local LLM (Ollama) to provide real-time attack vector analysis and payload generation.

![BosaTek Sentinel Demo](https://img.shields.io/badge/Security-Offensive-red?style=for-the-badge)
![Ollama Integrated](https://img.shields.io/badge/AI-Ollama--Llama3-blue?style=for-the-badge)
![Bash Script](https://img.shields.io/badge/Language-Bash-green?style=for-the-badge)

---

## 🚀 Key Features

* 5-Tab Tactical HUD: Dedicated full-screen views for Master Control, RustScan, FFUF, Burp Pro, and AI Brain.
* AI Integration (Sentinel-Brain): Custom Ollama Modelfile tuned to ignore generic AI safety lectures and provide direct SQLi, XSS, and Bypass payloads.
* Auto-Project Management: Burp Suite Pro automatically loads/saves project files into organized GitHub-ready writeup directories.
* High-Speed Recon: RustScan & FFUF integration with custom threading and extension filtering (.php, .html, .txt).
* Workflow Persistence: Instant session cleanup and "One-Command" exit logic.

---

## 🛠️ Installation & Setup

### 1. Prerequisites
Ensure you have the following installed: tmux, rustscan, ffuf, ollama, and Burp Suite Pro.

### 2. Setup Commands
Run these in your terminal to initialize the framework:
```bash
git clone https://github.com/Bosanac515/Bosatek-Sentinel.git
cd Bosatek-Sentinel
ollama create sentinel-brain -f Modelfile
chmod +x sentinel.sh
```
---

## 🎮 Execution

### How to Run
Launch the framework from your terminal:
```bash
./sentinel.sh
```

### Navigation & Controls
* Switch Tabs: Click the tab names at the bottom with your mouse, or use Ctrl + b followed by n (Next) or p (Previous).
* AI Brain: Switch to the AI_Brain tab to paste scan results for analysis or request specific bypass payloads.
* Exit: Type exit-sentinel in the Master tab to instantly kill all tools and close the session.

---

## ⌨️ Global Alias (Run from anywhere)
To run Sentinel by just typing 'sentinel' in any directory:
```bash
echo "alias sentinel='$(pwd)/sentinel.sh'" >> ~/.zshrc
source ~/.zshrc
```

---

## 📂 Directory Structure
Sentinel automatically organizes your work for GitHub writeups:
```bash
~/Documents/GitHub/Bosanac-Writeups/
└── [Room_Name]/
    └── [Room_Name].burp  # Auto-saved Burp Project file
```
---

## ⚖️ Disclaimer
This tool is for educational and authorized security testing only. Always ensure you have explicit, written permission before testing any target.

---
**Developed by [Bosanac515](https://github.com/Bosanac515)**
