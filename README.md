## Automation scripts to test Falco drivers on QEMU virtual machines.
## 🛠 Step 1: Install Required Dependencies


## 🛠 Step 1: Install Required Dependencies

First, install the required packages for running QEMU virtual machines and manipulating VM images.

```bash
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
                 virt-manager arping libguestfs-tools -y
```

### Enable KVM Permission

Add your user to the `kvm` group to allow hardware virtualization (for better VM performance):

```bash
sudo usermod -aG kvm $USER
```

⚠️ **Note:**
You must **logout and login again** for the new group permission to take effect.

## 🛠 Step 2: Project Structure

Before running the scripts, prepare the required files:

* Put VM images (`.qcow2`) into the **images/** folder.
* Put Falco driver files (`.ko`) that need to be tested into the **drivers/** folder.

Example:

```
project/
├── images/
│   └── rhel-8.0.qcow2
├── drivers/
│   └── falco_driver.ko
├── run_qemu.sh
├── auto_connect_and_test.sh
├── crawler_images.sh
...
```

You can also modify the Falco rules if needed.
The current scripts use **Falco version 0.36**, but you can change it to another version if required.


## 🚀 Step 3: Start the VM (Terminal 1)

You need to have the VM running so the automation script can connect to it. Use your `run_qemu.sh` script:

```bash
chmod +x run_qemu.sh
./run_qemu.sh

```

*Note: Keep this terminal open to monitor the kernel logs (`dmesg`) and the boot process.*

## 🧪 Step 4: Run the Automation (Terminal 2)

Once the VM reaches the login prompt, open a **new terminal tab** in the same directory and execute the test suite:

```bash
chmod +x auto_connect_and_test.sh
./auto_connect_and_test.sh

```

---

## 📂 Workflow Summary

The scripts will interact as follows:

1. **`run_qemu.sh`**: Creates the virtual hardware environment and maps port **2222** (host) to **22** (guest).
2. **`auto_connect_and_test.sh`**:
* Waits for the SSH port to open.
* Uploads the Falco binary from `./falco-0.36.0-x86_64`.
* Uploads your driver from the `./drivers` folder.
* Injects the driver, triggers a `cat /etc/shadow` event, and pulls back `local_events.json`.



## 🔍 Checking Results

After the script finishes, you can inspect the captured security events using `cat` or `jq`:

```bash
# View the raw JSON output
cat local_events.json

# If you have jq installed, view a pretty-printed version
cat local_events.json | jq

```

---