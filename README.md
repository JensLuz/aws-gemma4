# Gemma 4 26B on AWS — OpenTofu demo stack

Stands up a single EC2 GPU instance running:

- **Ollama** serving `gemma4:26b` with 64k context window and flash attention
- **Open WebUI** as the chat UI (custom-brandable, signups open)
- **Caddy** fronting everything with automatic HTTPS via Let's Encrypt
- **sslip.io** for DNS — no domain needed; `<ip>.sslip.io` resolves to your EIP

## Prereqs

- [OpenTofu](https://opentofu.org) 1.6+ (`tofu --version`)
- AWS CLI configured (`aws sts get-caller-identity`)
- A service quota allowing `g5.xlarge` — needs **4 vCPUs** of "Running On-Demand G and VT instances" (quota code `L-DB2E81BA`). Request via AWS Service Quotas console before deploying.

## Deploy

```bash
cd gemma-aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set allowed_ssh_cidr, admin_email, and optionally ollama_basic_auth_password
tofu init
tofu apply
```

After ~2 minutes you'll have the instance. The bootstrap (installing Ollama, pulling the 18 GB model, starting Open WebUI, provisioning the Let's Encrypt cert) takes another **8-10 minutes** in the background.

Watch progress:

```bash
tofu output -raw tail_bootstrap_log | bash
```

When it finishes, open the HTTPS URL:

```bash
tofu output https_url
```

First visit: create the admin account (first signup becomes admin). Subsequent signups get the `user` role immediately — no approval required.

## Ollama API & Claude Code integration

Set `ollama_basic_auth_password` in `terraform.tfvars` to expose the Ollama API at `/ollama/*` behind Bearer token auth:

```hcl
ollama_basic_auth_password = "your-secret-token"
```

Verify the endpoint after deploy:

```bash
curl -H "Authorization: Bearer your-secret-token" \
  $(tofu output -raw ollama_api_url)/api/tags
```

### Claude Code

```bash
ANTHROPIC_BASE_URL="$(tofu output -raw ollama_api_url)" \
ANTHROPIC_AUTH_TOKEN="your-secret-token" \
ANTHROPIC_API_KEY="" \
claude --model gemma4:26b
```

Add as an alias in `~/.zshrc` (macOS) or `~/.bashrc` (Linux):

```bash
alias claude-cloud='ANTHROPIC_BASE_URL="https://<ip>.sslip.io/ollama" ANTHROPIC_AUTH_TOKEN="your-secret-token" ANTHROPIC_API_KEY="" claude --model gemma4:26b'
```

> **Note:** tool calling (agentic file editing) works with Claude Code. OpenCode has a client-side parser bug (GH #20995) that drops tool calls — chat works but agentic mode does not.

## Context window

Default is **64k tokens**. To use 128k for a specific conversation:

- **Open WebUI:** Settings → Models → ⚙ → Advanced Params → Context Length → `131072`
- **API:** add `"options": {"num_ctx": 131072}` to your request body

128k forces a KV cache reallocation (~30-60s model reload) and uses most of the available VRAM headroom on A10G. Use it only when you need it.

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

| Configuration | Approx. cost |
|---|---|
| `g5.xlarge` on-demand (default) | ~$1.00/hr |
| `g5.xlarge` spot (`use_spot = true`) | ~$0.30/hr |
| 100 GB gp3 @ 1000 MB/s / 6000 IOPS | ~$18/month prorated |
| Data transfer | negligible for a demo |

Short-lived demos cost a few dollars. Don't forget `tofu destroy`.

## Security notes

- SSH restricted to your IP via `allowed_ssh_cidr`
- HTTPS enforced everywhere by Caddy (HSTS, nosniff, no-referrer headers)
- Ollama API at `/ollama/*` protected by Bearer token — leave `ollama_basic_auth_password` unset to keep the API private (SSH tunnel only)
- Open WebUI requires login; first user becomes admin
- Use a password manager or `openssl rand -hex 16` to generate the Bearer token — avoid special characters (`&`, `<`, `>`) as they require URL-encoding in some clients

## Troubleshooting

- **401 on Ollama API**: Bearer token in the request header must exactly match `ollama_basic_auth_password` in tfvars. Test with `curl -H "Authorization: Bearer TOKEN" .../ollama/api/tags`. If you changed the password, re-apply with `-replace=aws_instance.gemma`.
- **"Interrupted" in Claude Code**: ensure `ANTHROPIC_API_KEY=""` is set (clears any cached real Anthropic key) and that you are NOT embedding credentials in the URL — the Anthropic SDK sends Bearer, not Basic Auth.
- **Cert doesn't provision**: port 80 must be open (it is by default). Check `sudo journalctl -u caddy` on the box.
- **Model won't load**: check `nvidia-smi` and `sudo journalctl -u ollama` — 26B needs ~18 GB VRAM, fits A10G 24 GB.
- **WebUI unreachable**: `docker ps` to confirm `open-webui` is running. If not, check `docker logs open-webui`.
- **Bootstrap failed**: full log at `/var/log/gemma-bootstrap.log` on the instance.
- **Enable Caddy access logs** for request-level debugging: add `log { output stdout format json }` inside the site block in `/etc/caddy/Caddyfile`, then `sudo systemctl reload caddy` and tail with `sudo journalctl -u caddy -f -o cat`.
