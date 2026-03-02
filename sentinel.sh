#!/bin/bash
# ============================================================
#        BOSATEK SENTINEL - MODULAR LAUNCHER
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION="sentinel"

echo ""
echo "=========================================="
echo "      BOSATEK SENTINEL - MODULAR LAUNCHER"
echo "=========================================="
echo ""

# --- USER INPUT ---
read -p "  Target IP?  " TARGET_IP
read -p "  Room Name?  " ROOM_NAME

echo ""
echo "  Platform:"
echo "    1) TryHackMe"
echo "    2) HackTheBox"
echo "    3) Custom"
echo ""
read -p "  Platform (1/2/3): " PLATFORM_CHOICE

case "$PLATFORM_CHOICE" in
    1) PLATFORM="TryHackMe" ;;
    2) PLATFORM="HackTheBox" ;;
    3) PLATFORM="Custom" ;;
    *)
        echo "  [!] Invalid choice. Defaulting to TryHackMe."
        PLATFORM="TryHackMe"
        ;;
esac

# --- PATHS ---
ROOM_DIR="$HOME/Documents/GitHub/Bosanac-Writeups/$PLATFORM/$ROOM_NAME"

echo ""
echo "  [+] Platform  : $PLATFORM"
echo "  [+] Room Dir  : $ROOM_DIR"
echo "  [+] Target IP : $TARGET_IP"
echo ""

# --- CREATE DIRECTORY STRUCTURE ---
mkdir -p "$ROOM_DIR"/{nmap,ffuf,burp}
echo "  [+] Workspace directories created."

# --- KILL EXISTING SESSION ---
tmux kill-session -t "$SESSION" 2>/dev/null

# ============================================================
# TMUX SESSION SETUP
# ============================================================

# Tab 1: [Recon] - Horizontal split (top: scan, bottom: ffuf)
tmux new-session -d -s "$SESSION" -n "Recon"
tmux set-option -t "$SESSION" -g mouse on

# Top pane: RustScan -> Nmap
tmux send-keys -t "$SESSION:Recon" \
    "bash \"$SCRIPT_DIR/modules/recon.sh\" scan \"$TARGET_IP\" \"$ROOM_DIR\"" C-m

# Bottom pane: FFUF
tmux split-window -v -t "$SESSION:Recon"
tmux send-keys -t "$SESSION:Recon.1" \
    "bash \"$SCRIPT_DIR/modules/recon.sh\" ffuf \"$TARGET_IP\" \"$ROOM_DIR\"" C-m

# Tab 2: [Sentinel-AI] - Full screen Ollama
tmux new-window -t "$SESSION" -n "Sentinel-AI"
tmux send-keys -t "$SESSION:Sentinel-AI" \
    "bash \"$SCRIPT_DIR/modules/ai.sh\"" C-m

# Tab 3: [Net-Burp] - Vertical split (left: VPN, right: Burp Pro)
tmux new-window -t "$SESSION" -n "Net-Burp"

# Left pane: OpenVPN
tmux send-keys -t "$SESSION:Net-Burp" \
    "bash \"$SCRIPT_DIR/modules/network.sh\" vpn" C-m

# Right pane: Burp Pro
tmux split-window -h -t "$SESSION:Net-Burp"
tmux send-keys -t "$SESSION:Net-Burp.1" \
    "bash \"$SCRIPT_DIR/modules/network.sh\" burp \"$ROOM_DIR\" \"$ROOM_NAME\"" C-m

# --- FOCUS: Tab 1, Top Pane ---
tmux select-window -t "$SESSION:Recon"
tmux select-pane -t "$SESSION:Recon.0"

echo "  [+] Tmux session '$SESSION' ready."
echo "  [+] Tabs: [Recon] | [Sentinel-AI] | [Net-Burp]"
echo "  [+] Mouse mode: ON"
echo ""
echo "  Attaching..."
echo ""
tmux attach-session -t "$SESSION"
