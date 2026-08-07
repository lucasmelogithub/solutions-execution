# GCP — Prove Intel TDX Confidential VMs on Xeon (vs ARM) (30 minutes)

Welcome! Follow these steps **in order**. If you get stuck for more than 2 minutes, **raise your hand** — do not silently fall behind.

> Everything in this workshop runs from **Windows PowerShell**. When you see a gray box with commands, copy/paste it into PowerShell.

## What you will build

Deploy what looks like an innocent "small GCP VM", discover it has **no Intel TDX** (it's ARM), then switch to an Intel Xeon VM **and** turn on Confidential Computing, redeploy, and confirm Intel TDX is now active — showing how quickly you can move from ARM to a hardware-isolated Intel Confidential VM.

In order, you will:

1. Deploy a GCP `c4a-standard-2` VM (Axion — **ARM**, no TDX).
2. Prove Intel TDX is absent on the ARM box.
3. Change **two settings** — the machine type to `c3-standard-4` (Intel **Xeon**, Sapphire Rapids) and `enable_confidential_vm` to `true` — and redeploy.
4. Confirm Intel TDX is now active (`tdx_guest`, memory encryption, `confidentialInstanceType: TDX`).

## 1 Sign in to GCP

You will receive a **handout** with the sandbox `project-id`. Sign in with the workshop Google account (this opens a browser) and set your project:

```powershell
gcloud auth login
gcloud config set project <project-id-from-handout>

# ALSO required: Application Default Credentials, which Terraform uses
gcloud auth application-default login
```

> Why two `gcloud` logins? The first authenticates the **`gcloud` CLI**. The second writes Application Default Credentials to disk, which **Terraform's google provider** reads.

## 2 Move into the GCP folder

```powershell
cd terraform-gcp
```

## 3 Create your `terraform.tfvars`

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
code terraform.tfvars
```

Set `name_prefix` to a short **lowercase** prefix unique to you — your **first name** works well (e.g., `bob`), 3–10 letters, no spaces or capitals. **Paste the `project_id`** from your handout. **Leave `machine_type` set to `c4a-standard-2` and `enable_confidential_vm` set to `false` for now.** Save.

> `c4a` is GCP's Axion family — **ARM CPUs**. Looks innocent. Not Intel — and ARM has no Intel TDX.

## 4 Deploy and SSH in

```powershell
terraform init
terraform apply
```

1. Monitor the output. Terraform is telling GCP to create a new VM and an SSH keypair. The `terraform apply` step shows you the **plan** of what will be created.
2. Enter `yes` to confirm. Terraform will then create the resources.
3. When it finishes, Terraform writes an SSH keypair (`tfkey` / `tfkey.pub`) and an `ssh_config` file in this folder, with the Intel proxy already wired up.

Connect:

```powershell
ssh -F ssh_config vm
```

> If you're off Intel's network, use `ssh -F ssh_config_no_proxy vm` instead.

## 5 Look for Intel TDX (it won't be there)

Inside the VM:

```bash
lscpu | grep -i "model name\|architecture"
grep -o 'tdx[a-z_]*' /proc/cpuinfo | sort -u
sudo dmesg | grep -i "memory encryption"
```

`Architecture: aarch64`. The `grep` for `tdx` returns **nothing**, and `dmesg` shows **no** memory-encryption line.

**This is the teaching moment** — the customer asked for "a small cloud VM" and got an ARM box. Intel TDX (Trust Domain Extensions) is a **confidential computing** feature of **Intel Xeon** — it does not exist on ARM.

Exit the VM (`exit`).

## 6 Switch to Intel + turn on Confidential Computing, then redeploy

```powershell
code terraform.tfvars
```

Change **both** of these:

```hcl
machine_type           = "c4a-standard-2"
enable_confidential_vm = false
```

to:

```hcl
machine_type           = "c3-standard-4"
enable_confidential_vm = true
```

> Why two changes? Intel TDX needs **both** an Intel Xeon CPU (the `c3` family) **and** Confidential Computing switched on. A Confidential VM is a deliberate opt-in — the VM name alone never turns it on.

Save. Re-apply:

```powershell
terraform apply 
```

Watch the plan. It will show `1 to destroy, 1 to add`. In one small edit you just swapped an ARM box for an Intel Xeon **Confidential VM** — that's the power of Terraform: change a couple of variables and it rebuilds the underlying infrastructure for you.

Enter `yes` to confirm. Wait for the new VM to be created. (Confidential VMs boot and accept SSH a little slower than normal VMs — give it a minute.)

## 7 SSH in and confirm Intel TDX is active

```powershell
ssh -F ssh_config vm
```

Inside the VM:

```bash
lscpu | grep -i "model name\|architecture"
grep -o 'tdx[a-z_]*' /proc/cpuinfo | sort -u
sudo dmesg | grep -i "memory encryption"
```

`Architecture: x86_64`, `Model name: Intel(R) Xeon(R) ...`, the `grep` now prints **`tdx_guest`**, and `dmesg` reports **`Memory Encryption Features active: Intel TDX`**.

That last line is the proof: the guest's memory is hardware-encrypted inside an Intel TDX Trust Domain. Exit the VM (`exit`).

You can also confirm it from the control plane — no SSH needed. Back in PowerShell, replace `<name_prefix>` with the prefix you chose:

```powershell
gcloud compute instances describe smg-<name_prefix>-vm --zone us-central1-a --format="yaml(confidentialInstanceConfig)"
```

It prints `confidentialInstanceType: TDX`. You have now proven Intel TDX is active on the Intel Xeon Confidential VM and absent on the ARM box.

## Results

You have now proven that:

- Intel TDX is absent on ARM instances.
- Terraform can switch from ARM to an Intel Xeon Confidential VM with a two-line edit and one redeploy.
- Intel TDX confidential computing is active on the Intel Xeon (`c3`) Confidential VM.

---

## 8 Teardown — DO NOT SKIP

When you're done, tear everything down so the sandbox stops billing. Run from the `terraform-gcp` folder (or use the full path below):

```powershell
cd $HOME\solutions-execution\workshop\cloud-workshop\terraform-gcp
terraform destroy
```

1. Review the plan. Terraform shows you everything it will **destroy** (the VM and the SSH keypair).
2. Enter `yes` to confirm. Terraform tears down the resources and ends with `Destroy complete!`.

**Show your screen to a workshop assistant before you leave.**

---

## You did it

In about 30 minutes you went from zero to a working Intel-on-cloud evaluation:

- Used VSCode, Git, the `gcloud` CLI, and Terraform for the first time.
- Deployed a GCP VM, inspected the CPU, and changed **two Terraform variables** to move from ARM to an Intel Xeon Confidential VM.
- Saw firsthand that **Intel TDX needs both an Intel Xeon CPU and Confidential Computing explicitly enabled** — the VM name alone doesn't give it to you.
- Tore it all down.

That's the core check a customer runs when they evaluate Intel Confidential Computing in the cloud. Now you can demo it.

---

## Appendix — If something goes wrong

The issues you are most likely to hit, with the exact one-liner that fixes each. **Raise your hand** if a fix below doesn't unblock you within 2 minutes.

| You see | What it means | What to do |
| --- | --- | --- |
| `winget : The term 'winget' is not recognized` | Old Windows / IT disabled App Installer | Use **Path B** (manual installers) in step 1.2 |
| `cannot be loaded because running scripts is disabled on this system` | PowerShell execution policy | Run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`, then retry |
| `git` / `terraform` / `code` / `gcloud` `not recognized` right after install | PowerShell PATH is cached | **Close PowerShell, open a new one**, retry |
| `terraform apply` → `google: could not find default credentials` | Forgot the second `gcloud` login | Run `gcloud auth application-default login`, then `terraform apply` again |
| `terraform apply` → `network 'default' not found` | Project has no default VPC | **Raise your hand** — instructor needs to create it |
| `terraform apply` → `enable_confidential_vm = true requires a c3-standard machine type` | You set `enable_confidential_vm = true` but left an ARM `machine_type` | Set `machine_type = "c3-standard-4"` too, then re-apply |
| `terraform apply` → error mentioning `TDX` or the machine type isn't available in the zone | This zone lacks Intel TDX capacity right now | **Raise your hand** — the instructor will give you a supported zone |
| SSH → hangs right after you switch to the Confidential VM | Confidential VMs boot and accept SSH more slowly | Wait ~60 seconds, then retry `ssh -F ssh_config vm` |
| SSH → hangs at `connecting...` forever | `ssh_config` uses Intel proxy; you're off Intel network | Use `ssh -F ssh_config_no_proxy vm` instead |
| `terraform destroy` says `Error: ... still in use` | A previous `apply` was interrupted | Re-run `terraform destroy` once more (type `yes`); it usually clears |

When in doubt: from the `cloud-workshop` folder, run `.\prereqs\verify-tools.ps1` again — it confirms every tool is present and on PATH.
