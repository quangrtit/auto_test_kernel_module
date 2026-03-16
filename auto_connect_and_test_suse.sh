#!/bin/bash

# --- Configuration ---
VM_PORT=2222
VM_USER="root"
VM_PASS="root"
VM_HOST="localhost"
FALCO_DIR="./falco-0.36.0-x86_64"
DRIVER_PATH="./drivers/falco_rhel.ko" 

SSH_CMD="sshpass -p $VM_PASS ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p $VM_PORT"
SCP_CMD="sshpass -p $VM_PASS scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -P $VM_PORT"

echo "== 1. Waiting for VM SSH to become available =="
while ! nc -z $VM_HOST $VM_PORT; do
    echo "Still waiting for SUSE to boot..."
    sleep 2
done
echo "[+] VM is reachable via SSH."

echo "== 2. Preparing environment and copying assets == "
$SSH_CMD "$VM_USER@$VM_HOST" "rm -rf /root/falco /root/falco_events.json /etc/falco && mkdir -p /etc/falco"

$SCP_CMD "$FALCO_DIR/usr/bin/falco" "$VM_USER@$VM_HOST:/root/falco"

$SCP_CMD -r "$FALCO_DIR/etc/falco/"* "$VM_USER@$VM_HOST:/etc/falco/"
$SCP_CMD "$DRIVER_PATH" "$VM_USER@$VM_HOST:/root/falco.ko"

$SSH_CMD "$VM_USER@$VM_HOST" "chmod +x /root/falco"
echo "[+] Asset transfer complete."

echo "== 3. Loading Driver and Configuring Falco =="
$SSH_CMD "$VM_USER@$VM_HOST" "insmod /root/falco.ko 2>/dev/null || true"
$SSH_CMD "$VM_USER@$VM_HOST" "sed -i 's/json_output:.*/json_output: true/' /etc/falco/falco.yaml"
$SSH_CMD "$VM_USER@$VM_HOST" "sed -i 's/log_stderr:.*/log_stderr: true/' /etc/falco/falco.yaml"

echo "== 4. Starting Falco in Background =="
$SSH_CMD "$VM_USER@$VM_HOST" "nohup /root/falco -c /etc/falco/falco.yaml -r /etc/falco/falco_rules.yaml > /root/falco_events.json 2> /root/falco_error.log &"

echo "== 5. Triggering Security Events =="
$SSH_CMD "$VM_USER@$VM_HOST" "cat /etc/shadow > /dev/null && touch /etc/shadow"
echo "[+] Events triggered."
sleep 5

echo "== 6. Stopping Falco and Retrieving Logs =="
$SSH_CMD "$VM_USER@$VM_HOST" "pkill -SIGINT -f /root/falco && sync"
sleep 2
$SCP_CMD "$VM_USER@$VM_HOST:/root/falco_events.json" "./local_events.json" || true

echo "== 7. VERIFYING TEST RESULTS =="
if [ -s "./local_events.json" ]; then
    COUNT=$(grep -c "Sensitive file" local_events.json || true)
    echo "------------------------------------------------"
    echo "TEST SUCCESSFUL! Detected $COUNT events."
    echo "------------------------------------------------"
else
    echo "------------------------------------------------"
    echo "[!] FAILED: local_events.json is empty or not found."
    echo "== Debug: Content of /root/falco_error.log inside VM =="
    $SSH_CMD "$VM_USER@$VM_HOST" "cat /root/falco_error.log"
    echo "------------------------------------------------"
fi