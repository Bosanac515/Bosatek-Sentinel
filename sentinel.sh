#!/bin/bash
# ============================================================
# BOSATEK SENTINEL V3.1 — MASTER CONTROL
# Stability reset — clean multi-tab layout
# ============================================================

# --- CONFIGURATION ---
VPN_PATH="$HOME/Documents/THM.ovpn"
WRITEUP_BASE="$HOME/Documents/GitHub/Bosanac-Writeups/TryHackMe"
BURP_BASE="$HOME/Documents/GitHub/Bosanac-Writeups"
BURP_EXE="/opt/BurpSuitePro/BurpSuitePro"
WORDLIST="$HOME/Desktop/wordlists/dirb/common.txt"
SESSION="sentinel"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- COLORS ---
GOLD='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

# ============================================================
# MASTER MENU
# ============================================================
master_menu() {
    clear
    echo -e "${GOLD}${BOLD}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   BOSATEK SENTINEL V3.1 — MASTER CONTROL    ║"
    echo "  ║   Tactical Recon Framework                   ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${GREEN}[1]${RESET} New Engagement"
    echo -e "  ${GREEN}[2]${RESET} Resume Session"
    echo -e "  ${YELLOW}[3]${RESET} Tool Test  (Volatile — date-stamped)"
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
    mkdir -p "$BURP_BASE/$ROOM_NAME"

    echo -e "${GOLD}[*] Launching workspace: $ROOM_NAME ($TARGET_IP)${RESET}"
    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0 0
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

    echo -e "${YELLOW}[!] No live session found. Provide details to relaunch.${RESET}"
    echo ""
    read -p "  Target IP   : " TARGET_IP
    read -p "  Room Name   : " ROOM_NAME

    ROOM_DIR="$WRITEUP_BASE/$ROOM_NAME"
    if [[ ! -d "$ROOM_DIR" ]]; then
        echo -e "${RED}[!] Room directory not found: $ROOM_DIR${RESET}"
        sleep 2; master_menu; return
    fi

    mkdir -p "$BURP_BASE/$ROOM_NAME"
    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 0 0
}

# ============================================================
# OPTION 3: TOOL TEST — Volatile, date-stamped, VPN optional
# ============================================================
tool_test() {
    echo ""
    echo -e "${YELLOW}[!] TOOL TEST MODE — nothing saved permanently.${RESET}"
    echo ""
    read -p "  Target IP (test): " TARGET_IP

    ROOM_NAME="TEST_$(date +%Y%m%d_%H%M)"
    ROOM_DIR="/tmp/$ROOM_NAME"
    mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf" "$ROOM_DIR/logs"
    mkdir -p "$BURP_BASE/$ROOM_NAME"

    echo ""
    read -p "  Connect VPN? (y/n): " VPN_CHOICE
    local USE_VPN=0
    [[ "$VPN_CHOICE" =~ ^[Yy]$ ]] && USE_VPN=1

    launch_tmux "$TARGET_IP" "$ROOM_NAME" "$ROOM_DIR" 1 "$USE_VPN"
}

# ============================================================
# OPTION 4: SAVE & EXIT
# ============================================================
save_and_exit() {
    echo ""
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        LAST_DIR=$(tmux display-message -p -t "$SESSION" '#{pane_current_path}' 2>/dev/null)
        if [[ -n "$LAST_DIR" && -d "$LAST_DIR/logs" ]]; then
            echo "Session closed: $(date)" >> "$LAST_DIR/logs/session.log"
        fi
        tmux kill-session -t "$SESSION"
        echo -e "${GREEN}[*] Session terminated.${RESET}"
    else
        echo -e "${YELLOW}[*] No active session.${RESET}"
    fi
    echo -e "${GOLD}[*] Bosatek Sentinel V3.1 — goodbye.${RESET}"
    exit 0
}

# ============================================================
# TMUX WORKSPACE LAUNCHER
# launch_tmux <TARGET_IP> <ROOM_NAME> <ROOM_DIR> <VOLATILE 0|1> <USE_VPN 0|1>
#
# ┌──────────────────────────────────────────────────────────┐
# │  Tab 1 [Recon]                                           │
# │  ┌─────────────────────────────────────────────────┐    │
# │  │  Pane 0 (top ~60%)  :  RustScan / Nmap          │    │
# │  ├─────────────────────────────────────────────────┤    │
# │  │  Pane 1 (bottom 40%):  FFUF  -s -ic -mc 200..   │    │
# │  └─────────────────────────────────────────────────┘    │
# │                                                          │
# │  Tab 2 [Workspace]                                       │
# │  ┌──────────────────────┬──────────────────────────┐    │
# │  │  Pane 0 (left 45%)   │  Pane 1 (right 55%)      │    │
# │  │  AI Brain watcher    │  MASTER TERMINAL          │    │
# │  │  tail -F summary.log │  Clean Zsh — type freely  │    │
# │  └──────────────────────┴──────────────────────────┘    │
# │                                                          │
# │  Tab 3 [Writeup]                                         │
# │  ┌─────────────────────────────────────────────────┐    │
# │  │  nano checklist.md (or writeup.md)               │    │
# │  └─────────────────────────────────────────────────┘    │
# └──────────────────────────────────────────────────────────┘
# ============================================================
launch_tmux() {
    local TARGET_IP="$1"
    local ROOM_NAME="$2"
    local ROOM_DIR="$3"
    local VOLATILE="$4"
    local USE_VPN="$5"
    local BURP_PROJECT="$BURP_BASE/$ROOM_NAME/$ROOM_NAME.burp"

    tmux kill-session -t "$SESSION" 2>/dev/null
    tmux start-server 2>/dev/null || true

    # ----------------------------------------------------------
    # TMUX OPTIONS — bare essentials only, no custom mouse hooks
    # ----------------------------------------------------------

    # Prefix: Ctrl+a
    # bind C-a send-prefix → double-tap C-a sends literal C-a to the app
    tmux set -g prefix C-a
    tmux unbind C-b
    tmux bind C-a send-prefix

    # Mouse: on, zero custom bindings
    # Unbind tmux's default right-click pane menu so the terminal
    # emulator receives the click and shows the native Kali context menu
    tmux set -g mouse on
    tmux unbind-key -T root MouseDown3Pane

    # Status bar — gold theme
    tmux set -g status-style          "bg=colour235,fg=colour220"
    tmux set -g status-left           "#[fg=colour220,bold] V3.1 #[fg=colour250]| "
    tmux set -g status-right          "#[fg=colour220,bold] $ROOM_NAME #[fg=colour250]| %H:%M "
    tmux set -g window-status-current-style "fg=colour220,bold"

    # ----------------------------------------------------------
    # TAB 1 [Recon] — horizontal (top/bottom) split
    #   Pane 0 (top  ~60%) : RustScan / Nmap
    #   Pane 1 (bottom 40%): FFUF  -s -ic -mc 200,301,302
    # ----------------------------------------------------------
    tmux new-session -d -s "$SESSION" -n "Recon"

    # Pane 0: export env + start RustScan
    tmux send-keys -t "$SESSION:Recon.0" \
        "export IP='$TARGET_IP' ROOM='$ROOM_NAME' ROOM_DIR='$ROOM_DIR' VOLATILE=$VOLATILE WORDLIST='$WORDLIST'" C-m
    tmux send-keys -t "$SESSION:Recon.0" \
        "source '$SCRIPT_DIR/modules/recon.sh' && run_nmap '$TARGET_IP' '$ROOM_DIR' $VOLATILE" C-m

    # Split horizontally (top/bottom): -v flag, keep bottom at 40%
    tmux split-window -v -t "$SESSION:Recon.0" -p 40

    # Pane 1: export env + start FFUF
    tmux send-keys -t "$SESSION:Recon.1" \
        "export IP='$TARGET_IP' ROOM='$ROOM_NAME' ROOM_DIR='$ROOM_DIR' VOLATILE=$VOLATILE WORDLIST='$WORDLIST'" C-m
    tmux send-keys -t "$SESSION:Recon.1" \
        "source '$SCRIPT_DIR/modules/recon.sh' && run_ffuf '$TARGET_IP' '$ROOM_DIR' $VOLATILE" C-m

    # ----------------------------------------------------------
    # TAB 2 [Workspace] — vertical (left/right) split
    #   Pane 0 (left  45%): AI Brain background + tail -F summary.log
    #   Pane 1 (right 55%): MASTER TERMINAL — clean Zsh, user types here
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Workspace"

    # Pane 0 (left): start ai_brain_loop in background, then tail summary.log
    # The loop writes its status to ai_brain.log — it does NOT touch the
    # Master Terminal pane and has no access to user input.
    tmux send-keys -t "$SESSION:Workspace.0" \
        "source '$SCRIPT_DIR/modules/ai_brain.sh'" C-m
    tmux send-keys -t "$SESSION:Workspace.0" \
        "ai_brain_loop '$ROOM_DIR' >> '$ROOM_DIR/logs/ai_brain.log' 2>&1 &" C-m
    tmux send-keys -t "$SESSION:Workspace.0" \
        "echo '[AI-Brain] Watcher running (→ ai_brain.log)'; echo ''; touch '$ROOM_DIR/logs/summary.log'; tail -F '$ROOM_DIR/logs/summary.log'" C-m

    # Split vertically (left/right): -h flag, right pane gets 55%
    tmux split-window -h -t "$SESSION:Workspace.0" -p 55

    # Pane 1 (right): Master Terminal
    # — export env, gold banner, launch Burp in background, then CLEAN ZSH.
    # Nothing blocks or loops here. User can type immediately.
    tmux send-keys -t "$SESSION:Workspace.1" \
        "export IP='$TARGET_IP' ROOM='$ROOM_NAME' ROOM_DIR='$ROOM_DIR' VOLATILE=$VOLATILE WORDLIST='$WORDLIST'; clear" C-m

    tmux send-keys -t "$SESSION:Workspace.1" \
        "printf '\033[1;33m╔══════════════════════════════════════════════╗\n║  BOSATEK SENTINEL V3.1 — MASTER TERMINAL     ║\n╚══════════════════════════════════════════════╝\033[0m\n\n  \033[0;32mTarget :\033[0m %s\n  \033[0;32mRoom   :\033[0m %s\n  \033[0;32mDir    :\033[0m %s\n\n' \"\$IP\" \"\$ROOM\" \"\$ROOM_DIR\"" C-m

    # Launch Burp Pro — directory already created above.
    # Background + disown so no job-control noise in the terminal.
    tmux send-keys -t "$SESSION:Workspace.1" \
        "mkdir -p '$BURP_BASE/$ROOM_NAME' && '$BURP_EXE' --project-file='$BURP_PROJECT' &>/dev/null & disown; echo '[Burp] Launching $BURP_PROJECT...'" C-m

    # VPN (only if requested) — background openvpn, log to ~/vpn.log
    if [[ "$USE_VPN" -eq 1 ]]; then
        tmux send-keys -t "$SESSION:Workspace.1" \
            "sudo openvpn '$VPN_PATH' > '$HOME/vpn.log' 2>&1 & echo '[VPN] OpenVPN starting → ~/vpn.log'" C-m
    fi

    # Master Terminal is now at a clean Zsh prompt — focus it
    tmux select-pane -t "$SESSION:Workspace.1"

    # ----------------------------------------------------------
    # TAB 3 [Writeup] — single pane, nano checklist.md
    # ----------------------------------------------------------
    tmux new-window -t "$SESSION" -n "Writeup"
    tmux send-keys -t "$SESSION:Writeup" \
        "touch '$ROOM_DIR/checklist.md' '$ROOM_DIR/writeup.md'; nano '$ROOM_DIR/checklist.md'" C-m

    # ----------------------------------------------------------
    # Land on Tab 2 [Workspace], Master Terminal (right pane)
    # ----------------------------------------------------------
    tmux select-window -t "$SESSION:Workspace"
    tmux select-pane -t "$SESSION:Workspace.1"
    tmux attach-session -t "$SESSION"
}

# ============================================================
# ENTRY POINT
# ============================================================
master_menu
