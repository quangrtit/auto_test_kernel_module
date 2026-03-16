#!/bin/bash

# --- Configuration ---
VM_PORT=2222
VM_USER="root"
VM_PASS="root"
VM_HOST="localhost"
FALCO_DIR="./falco-0.36.0-x86_64"
DRIVER_PATH="./drivers/falco_rhel.ko"

# SSH/SCP commands with quiet mode and suppressed host checking to clean up logs
SSH_CMD="sshpass -p $VM_PASS ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p $VM_PORT"
SCP_CMD="sshpass -p $VM_PASS scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -P $VM_PORT"

echo "== 1. Waiting for VM SSH to become available =="
while ! nc -z $VM_HOST $VM_PORT; do
    echo "Still waiting for VM to boot..."
    sleep 2
done
echo "[+] VM is reachable via SSH."

echo "== 2. Preparing environment and copying assets =="
# Clean up previous runs and create necessary directories
$SSH_CMD "$VM_USER@$VM_HOST" "mkdir -p /etc/falco/rules.d && rm -f /root/falco_events.json"
$SCP_CMD "$FALCO_DIR/usr/bin/falco" "$VM_USER@$VM_HOST:/root/"
$SCP_CMD -r "$FALCO_DIR/etc/falco" "$VM_USER@$VM_HOST:/etc/"
$SCP_CMD "$DRIVER_PATH" "$VM_USER@$VM_HOST:/root/falco.ko"
echo "[+] Asset transfer complete."

echo "== 3. Loading Driver and Configuring Falco =="
# Try to insert module and capture error if any
LOAD_ERR=$($SSH_CMD "$VM_USER@$VM_HOST" "insmod /root/falco.ko 2>&1 || echo 'FAILED'")
if [[ "$LOAD_ERR" == *"FAILED"* ]]; then
    echo "[!] WARNING: Kernel driver failed to load (Invalid format or mismatch)."
    echo "    Error detail: $LOAD_ERR"
else
    echo "[+] Driver loaded successfully."
fi

# Enable JSON output for automated parsing
$SSH_CMD "$VM_USER@$VM_HOST" "sed -i 's/json_output:.*/json_output: true/' /etc/falco/falco.yaml"

echo "== 4. Starting Falco in Background =="
$SSH_CMD "$VM_USER@$VM_HOST" "nohup /root/falco -c /etc/falco/falco.yaml -r /etc/falco/falco_rules.yaml > /root/falco_events.json 2>&1 &"
sleep 5 # Allow Falco engine to initialize

echo "== 5. Triggering Security Events (Simulating Activity) =="
$SSH_CMD "$VM_USER@$VM_HOST" "cat /etc/shadow > /dev/null"
$SSH_CMD "$VM_USER@$VM_HOST" "touch /etc/shadow"
echo "[+] Triggered 'Sensitive file access' events (cat/touch /etc/shadow)."
sleep 5 # Allow time for events to be flushed to disk

echo "== 6. Stopping Falco and Retrieving Logs =="
$SSH_CMD "$VM_USER@$VM_HOST" "pkill -f falco"
$SCP_CMD "$VM_USER@$VM_HOST:/root/falco_events.json" "./local_events.json"
echo "[+] Local log file saved: ./local_events.json"

echo "== 7. VERIFYING TEST RESULTS =="
if [ -f "./local_events.json" ]; then
    # Search for specific alert strings in the JSON output
    COUNT=$(grep -c "Sensitive file opened" local_events.json || true)
    
    if [ "$COUNT" -gt 0 ]; then
        echo "------------------------------------------------"
        echo "TEST SUCCESSFUL!"
        echo "Detected $COUNT security events in the logs."
        echo "Last Alert Sample:"
        grep "Sensitive file opened" local_events.json | tail -n 1
        echo "------------------------------------------------"
    else
        echo "------------------------------------------------"
        echo "TEST FAILED: No events detected in JSON log."
        echo "Check 'dmesg' in VM to confirm the driver is active."
        echo "------------------------------------------------"
    fi
else
    echo "[!] Error: local_events.json was not retrieved."
fi