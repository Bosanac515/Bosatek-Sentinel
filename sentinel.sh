#!/bin/bash

# --- CONFIGURATION ---
VPN_PATH="$HOME/Documents/THM.ovpn"
WRITEUP_BASE="$HOME/Documents/GitHub/Bosanac-Writeups/TryHackMe"
NOTES_PATH="$HOME/Documents/GitHub/Pentesting-DB/Writeups"
SESSION="sentinel"

# --- INPUTS ---
echo "--- Bosatek Sentinel Tactical Launch ---"
read -p "Target IP: " TARGET_IP
read -p "Room Name: " ROOM_NAME

# --- PREP ENVIRONMENT ---
ROOM_DIR="$WRITEUP_BASE/$ROOM_NAME"
mkdir -p "$ROOM_DIR/nmap" "$ROOM_DIR/ffuf"
cd "$ROOM_DIR"

# --- START TMUX SESSION ---
# Create session and hide the status bar for a clean look
tmux new-session -d -s $SESSION -n "Dashboard"

# Pane 0: Master Control / Active Shell (Left)
tmux send-keys -t $SESSION:0.0 "export IP=$TARGET_IP; clear; echo 'Target: $TARGET_IP'" C-m

# Pane 1: VPN (Top Right)
tmux split-window -h -t $SESSION:0
tmux send-keys -t $SESSION:0.1 "sudo openvpn $VPN_PATH" C-m

# Pane 2: Tactical AI (Bottom Right)
tmux split-window -v -t $SESSION:0.1
tmux send-keys -t $SESSION:0.2 "ollama run bosatek-sentinel" C-m

# Pane 3: The Recon/Wordlist Menu (Bottom Left)
tmux split-window -v -t $SESSION:0.0
tmux send-keys -t $SESSION:0.3 "echo 'Select Wordlist for FFUF:'; 
select wl in 'Common' 'Raft-Medium' 'Pentesting-DB-Custom'; do
  case \$wl in
    'Common') WORDLIST='/usr/share/wordlists/dirb/common.txt'; break;;
    'Raft-Medium') WORDLIST='/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt'; break;;
    'Pentesting-DB-Custom') WORDLIST='$HOME/Documents/GitHub/Pentesting-DB/Main/FFUF/custom.txt'; break;;
  esac
done; 
ffuf -w \$WORDLIST -u http://$TARGET_IP/FUZZ -o ffuf/hits.json" C-m

# --- THE AUTO-BURP MONITOR (New Window) ---
tmux new-window -t $SESSION -n "Auto-Burp"
tmux send-keys -t $SESSION:1 "while true; do 
  if [ -f ffuf/hits.json ]; then
    cat ffuf/hits.json | jq -r '.results[] | .url' | xargs -I {} burpsuite --open-url {}
  fi
  sleep 30
done" C-m

# Attach to the session
tmux select-window -t $SESSION:0
tmux attach-session -t $SESSION
