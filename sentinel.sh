#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V2
# Main launcher with Master Menu and Tmux workspace setup
# ============================================================

# --- CONFIGURATION ---
VPN_PATH="$HOME/Documents/THM.ovpn"
WRITEUP_BASE="$HOME/Documents/GitHub/Bosanac-Writeups/TryHackMe"
WORDLIST="$HOME/Desktop/wordlists/dirb/common.txt"
SESSION="sentinel"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================
# MASTER MENU
# ============================================================
master_menu() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║        BOSATEK SENTINEL V2               ║"
    echo "  ║        Tactical Recon Framework          ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${GREEN}[1]${RESET} New Engagement"
    echo -e "  ${GREEN}[2]${RESET} Resume Session"
    echo -e "  ${YELLOW}[3]${RESET} Tool Test (Volatile)"
    echo -e "  ${RED}[4]${RESET} Save & Exit"
    echo ""
    read -p "  Select option [1-4]: " CHOICE

    case "$CHOICE" in
        1) new_engagement ;;
        2) resume_session ;;
        3) tool_test ;;
        4) save_and_exit ;;
        *) echo -e "${RED}[!] Invalid option.${RESET}"; sleep 1; master_menu ;;
    esac
}

# ============================================================
# OPTION 1: NEW ENGAGEMENT
# ============================================================
new_engagement() {
    echo ""
    read -p "  Target IP   : " TARGET_IP
    read -p "  Room Name   : " ROOM_NAME

    if [[ -z "$TARGET_IP" || -z "$ROOM_NAME" ]]; then
        echo -e "${RED}[!] Target IP and Room Name are required.${RESET}"
        sleep 1; master_menu; return
    fi

    ROOM_DIR="$WRITEUP_BASE/$ROOM_NAME"
    mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf" "$ROOM_DIR/logs"
    cd "$ROOM_DIR" || exit 1

    echo -e "${GREEN}[*] Launching workspace for: $ROOM_NAME ($TARGET_IP)${RESET}"
    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0
}

# ============================================================
# OPTION 2: RESUME SESSION
# ============================================================
resume_session() {
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        echo -e "${GREEN}[*] Reattaching to existing session...${RESET}"
        tmux attach-session -t "$SESSION"
        return
    fi

    echo -e "${YELLOW}[!] No live session found. Provide target to relaunch.${RESET}"
    echo ""
    read -p "  Target IP   : " TARGET_IP
    read -p "  Room Name   : " ROOM_NAME

    ROOM_DIR="$WRITEUP_BASE/$ROOM_NAME"
    if [[ ! -d "$ROOM_DIR" ]]; then
        echo -e "${RED}[!] Room directory not found: $ROOM_DIR${RESET}"
        sleep 2; master_menu; return
    fi

    cd "$ROOM_DIR" || exit 1
    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0
}

# ============================================================
# OPTION 3: TOOL TEST (VOLATILE — no output saved)
# ============================================================
tool_test() {
    echo ""
    echo -e "${YELLOW}[!] TOOL TEST MODE — all output is volatile and will NOT be saved.${RESET}"
    echo ""
    read -p "  Target IP (test): " TARGET_IP

    ROOM_NAME="VOLATILE_TEST_$(date +%s)"
    ROOM_DIR="/tmp/$ROOM_NAME"
    mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf" "$ROOM_DIR/logs"
    cd "$ROOM_DIR" || exit 1

    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 1
}

# ============================================================
# OPTION 4: SAVE & EXIT
# ============================================================
save_and_exit() {
    echo ""
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        # Capture any pending session notes before killing
        LAST_DIR=$(tmux display-message -p -t "$SESSION" '#{pane_current_path}' 2>/dev/null)
        if [[ -n "$LAST_DIR" && -d "$LAST_DIR/logs" ]]; then
            echo "Session closed: $(date)" >> "$LAST_DIR/logs/session.log"
            echo -e "${GREEN}[*] Session log saved to: $LAST_DIR/logs/session.log${RESET}"
        fi
        tmux kill-session -t "$SESSION"
        echo -e "${GREEN}[*] Tmux session terminated.${RESET}"
    else
        echo -e "${YELLOW}[*] No active session to close.${RESET}"
    fi
    echo -e "${CYAN}[*] Bosatek Sentinel V2 — goodbye.${RESET}"
    exit 0
}

# ============================================================
# TMUX WORKSPACE LAUNCHER
# launch_tmux <TARGET_IP> <ROOM_NAME> <ROOM_DIR> <VOLATILE 0|1>
# ============================================================
launch_tmux() {
    local TARGET_IP="$1"
    local ROOM_NAME="$2"
    local ROOM_DIR="$3"
    local VOLATILE="$4"

    # Kill any stale session
    tmux kill-session -t "$SESSION" 2>/dev/null

    # ----------------------------------------------------------
    # Create session — TAB 1: Control
    # ----------------------------------------------------------
    tmux new-session -d -s "$SESSION" -n "Control"

    # Set prefix to Ctrl+a (unbind default Ctrl+b)
    tmux set-option -g -t "$SESSION" prefix C-a
    tmux unbind-key -T prefix C-b 2>/dev/null || true
    tmux bind-key -T prefix C-a send-prefix

    # Enable mouse mode
    tmux set-option -g -t "$SESSION" mouse on

    # Status bar colour
    tmux set-option -g -t "$SESSION" status-bg colour235
    tmux set-option -g -t "$SESSION" status-fg colour250
    tmux set-option -g -t "$SESSION" status-left "#[fg=colour46,bold] SENTINEL V2 #[fg=colour250]| "
    tmux set-option -g -t "$SESSION" status-right "#[fg=colour220] $ROOM_NAME #[fg=colour250]| %H:%M "

    # TAB 1: Control — env setup + recon split
    tmux send-keys -t "$SESSION:Control" \
        "export IP='$TARGET_IP'; export ROOM='$ROOM_NAME'; export ROOM_DIR='$ROOM_DIR'; export VOLATILE=$VOLATILE; clear; echo '=== BOSATEK SENTINEL V2 ==='; echo 'Target : $TARGET_IP'; echo 'Room   : $ROOM_NAME'; echo 'Dir    : $ROOM_DIR'; echo ''" C-m

    # Split bottom: recon runner
    tmux split-window -v -t "$SESSION:Control" -l 12
    tmux send-keys -t "$SESSION:Control.1" \
        "source '$SCRIPT_DIR/modules/recon.sh' && run_recon '$TARGET_IP' '$ROOM_DIR' $VOLATILE" C-m

    tmux select-pane -t "$SESSION:Control.0"

    # ----------------------------------------------------------
    # TAB 2: AI-Brain
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "AI-Brain"
    tmux send-keys -t "$SESSION:AI-Brain" "ollama run bosatek-sentinel" C-m

    # Bottom split: AI background loop watching summary.log
    tmux split-window -v -t "$SESSION:AI-Brain" -l 8
    tmux send-keys -t "$SESSION:AI-Brain.1" \
        "source '$SCRIPT_DIR/modules/ai_brain.sh' && ai_brain_loop '$ROOM_DIR'" C-m

    tmux select-pane -t "$SESSION:AI-Brain.0"

    # ----------------------------------------------------------
    # TAB 3: Network
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Network"

    # Left pane: VPN
    tmux send-keys -t "$SESSION:Network" \
        "echo '[*] Starting OpenVPN...'; sudo openvpn '$VPN_PATH' 2>&1 | tee '$HOME/vpn.log'" C-m

    # Right pane: wait_for_vpn watcher + Burp placeholder
    tmux split-window -h -t "$SESSION:Network"
    tmux send-keys -t "$SESSION:Network.1" \
        "source '$SCRIPT_DIR/modules/network.sh' && wait_for_vpn '$HOME/vpn.log' && echo '[+] VPN tunnel confirmed. Ready for traffic.'" C-m

    # ----------------------------------------------------------
    # TAB 4: Monitor
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Monitor"

    # Left pane: live log tail
    tmux send-keys -t "$SESSION:Monitor" \
        "echo '[*] Monitor live. Tailing logs...'; tail -F '$ROOM_DIR/logs/summary.log' 2>/dev/null" C-m

    # Right pane: checklist watcher
    tmux split-window -h -t "$SESSION:Monitor"
    tmux send-keys -t "$SESSION:Monitor.1" \
        "watch -n 5 'cat \"$ROOM_DIR/checklist.md\" 2>/dev/null || echo \"No checklist yet...\"'" C-m

    # ----------------------------------------------------------
    # Focus Control tab and attach
    # ----------------------------------------------------------
    tmux select-window -t "$SESSION:Control"
    tmux select-pane -t "$SESSION:Control.0"
    tmux attach-session -t "$SESSION"
}

# ============================================================
# ENTRY POINT
# ============================================================
master_menu
