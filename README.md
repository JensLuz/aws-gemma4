# Gemma 4 26B on AWS — OpenTofu demo stack

Stands up a single EC2 GPU instance running:

- **Ollama** serving `gemma4:26b`
- **Open WebUI** as the chat UI (custom-brandable)
- **Caddy** fronting it with automatic HTTPS via Let's Encrypt
- **sslip.io** for DNS — no domain needed; any `<ip>.sslip.io` resolves to that IP

## Prereqs

- [OpenTofu](https://opentofu.org) 1.6+ (`tofu --version`)
- AWS CLI configured (`aws sts get-caller-identity`)
- A service quota allowing `g5.xlarge` in your chosen region — needs 4 vCPUs of "Running On-Demand G and VT instances" (request via AWS console if needed)

## Deploy

```bash
cd gemma-aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set allowed_ssh_cidr and admin_email

tofu init
tofu apply
```

After ~2 minutes you'll have the instance. The bootstrap (installing Ollama, pulling the 18GB model, starting Open WebUI, provisioning the Let's Encrypt cert) takes another **5-10 minutes** in the background.

Watch progress:

```bash
tofu output -raw tail_bootstrap_log | bash
```

When it finishes, open the HTTPS URL:

```bash
tofu output https_url
```

First visit: create the admin account (first signup becomes admin). Disable signups in Settings → Admin afterwards.

## Customize the UI

Log in → Settings → Interface:

- Upload your personal logo
- Set a custom avatar for the model
- Tweak theme colors

## Destroy

```bash
tofu destroy
```

Deletes the instance, EIP, security group, and keypair. **~$0 residual cost.**

## Cost

- `g5.xlarge` on-demand: ~$1.00/hr (4 vCPU / 16GB RAM, default — uses 16GB swap to handle model verify)
- `g5.2xlarge` on-demand: ~$1.21/hr (8 vCPU / 32GB RAM, smoother but needs higher quota)
- Spot (`use_spot = true`): ~70% cheaper
- 100 GB gp3 @ 1000 MB/s / 6000 IOPS: ~$18/month prorated
- Data transfer: negligible for a demo

Short-lived demos cost a few dollars. Don't forget `tofu destroy`.

## Security notes

- SSH restricted to your IP via `allowed_ssh_cidr`
- HTTPS enforced by Caddy
- Open WebUI requires login (first user = admin)
- Consider enabling **Cloudflare Access** or an IP allowlist on port 443 if the demo is sensitive

## Troubleshooting

- **Cert doesn't provision**: port 80 must be open (it is, by default). Check `sudo journalctl -u caddy` on the box.
- **Model won't load**: check `nvidia-smi` and `sudo journalctl -u ollama` — 26B needs ~18GB VRAM, fits in A10G 24GB.
- **Webui unreachable**: `docker ps` to confirm `open-webui` is running. If not, `docker logs open-webui`.
- **Bootstrap failed**: full log at `/var/log/gemma-bootstrap.log` on the instance.
