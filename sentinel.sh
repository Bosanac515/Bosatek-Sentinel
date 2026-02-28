#!/bin/bash

# --- CONFIGURATION ---
VPN_PATH="$HOME/Documents/THM.ovpn"
WRITEUP_BASE="$HOME/Documents/GitHub/Bosanac-Writeups/TryHackMe"
WORDLIST="~/Desktop/wordlists/dirb/common.txt"
SESSION="sentinel"

echo "--- Bosatek Sentinel Modular Launch ---"
read -p "Target IP: " TARGET_IP
read -p "Room Name: " ROOM_NAME

# --- PREP ENVIRONMENT ---
ROOM_DIR="$WRITEUP_BASE/$ROOM_NAME"
mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf"
cd "$ROOM_DIR"

# --- LAUNCH TMUX ---
tmux new-session -d -s $SESSION -n "Master-Control"
tmux set-option -g mouse on

# ==========================================
# TAB 1: MASTER CONTROL (Splits)
# ==========================================
# Left Pane (0.0): Active Shell
tmux send-keys -t $SESSION:0 "export IP=$TARGET_IP; clear; echo 'System Ready. Target: $TARGET_IP'" C-m

# Right Top Pane (0.1): RustScan
tmux split-window -h -t $SESSION:0
tmux send-keys -t $SESSION:0.1 "rustscan -a $TARGET_IP -- -A -sC -oN nmap/initial.txt" C-m

# Right Bottom Pane (0.2): FFUF (Your custom command)
tmux split-window -v -t $SESSION:0.1
tmux send-keys -t $SESSION:0.2 "ffuf -w $WORDLIST -u http://$TARGET_IP/FUZZ -e .php,.html,.txt -t 100 -o ffuf/hits.json" C-m

# ==========================================
# TAB 2: SENTINEL-AI (Full Screen)
# ==========================================
tmux new-window -t $SESSION -n "Sentinel-AI"
tmux send-keys -t $SESSION:1 "ollama run bosatek-sentinel" C-m

# ==========================================
# TAB 3: NETWORK & BURP PRO (Splits)
# ==========================================
tmux new-window -t $SESSION -n "Net-Burp"

# Left Pane: VPN (Using the new NOPASSWD trick)
tmux send-keys -t $SESSION:2 "sudo openvpn $VPN_PATH" C-m

# Right Pane: Burp Pro Project Auto-Open
tmux split-window -h -t $SESSION:2
tmux send-keys -t $SESSION:2.1 "echo 'Waiting for FFUF hits to send to Burp Pro...'; while true; do sleep 10; done" C-m

# Attach to Tab 1, Pane 0 (Your active shell)
tmux select-window -t $SESSION:0
tmux select-pane -t $SESSION:0.0
tmux attach-session -t $SESSION
