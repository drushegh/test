# Networking and SSH

## Inspecting the network

```bash
ip addr; ip route                 # interfaces and routing (not ifconfig/route)
ss -tulpn                          # listening sockets + owning process
resolvectl status                  # DNS (systemd-resolved)
ping host; traceroute host; mtr host
curl -v https://host/health        # app-level reachability
```

`ss` replaces `netstat`; `ip` replaces `ifconfig`/`route`. To find *what's
listening on a port and which process owns it*, `ss -tulpn` is the first stop.

## DNS

Most modern distros use **systemd-resolved** (`resolvectl`); `/etc/resolv.conf`
is often a symlink it manages. Per-link DNS, caching and DNSSEC live here. On
cloud VMs DNS is usually provided by the platform — don't hand-edit
`/etc/resolv.conf` if resolved manages it; configure the link or netplan/
NetworkManager instead.

## Firewall — default deny

Pick one front-end and be consistent. All are backed by **nftables** now.

```bash
# ufw (Ubuntu/Debian)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp          # keep SSH BEFORE enabling, or you lock out
sudo ufw allow 443/tcp
sudo ufw enable; sudo ufw status verbose
```

```bash
# firewalld (RHEL) — zone-based
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload; sudo firewall-cmd --list-all
```

Rules: deny inbound by default, open only documented ports, and **always keep
your current SSH session's access** when changing rules remotely. For egress
control on sensitive hosts, restrict outbound too. nftables directly
(`/etc/nftables.conf`) when you need explicit, fine-grained rule sets.

## SSH server hardening

sshd uses the **first** value it reads for each keyword, and most current
distros (Debian/Ubuntu, Fedora/RHEL 9+) start `sshd_config` with
`Include /etc/ssh/sshd_config.d/*.conf`, read in lexical order. So a setting
at the bottom of `sshd_config` loses to any drop-in, and cloud images often
ship one (e.g. cloud-init's `50-cloud-init.conf` with
`PasswordAuthentication yes`). Put hardening in an early-sorting drop-in such
as `/etc/ssh/sshd_config.d/00-hardening.conf` (or remove/override the
conflicting drop-in), then check the *effective* config with `sshd -T`:

```
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowGroups ssh-users
X11Forwarding no
```

```bash
sudo sshd -t                 # validate config BEFORE reloading
sudo sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication) '
                             # effective values after Include/first-match
sudo systemctl reload ssh    # (ssh or sshd depending on distro)
```

- **Key-only, no root login** is the baseline. Manage keys via
  `~/.ssh/authorized_keys` (or central CA/OIDC for fleets).
- Validate with `sshd -t` and keep a second session open while reloading — a
  bad config plus a closed session is a lockout.
- Pair with **fail2ban** and a firewall (`security-hardening.md`); consider a
  non-standard port only as noise reduction, not security.

## Remote access patterns

Bastion/jump host for private fleets; `ssh -J bastion target` to hop. On Azure,
prefer Bastion / Just-in-time access over public SSH where possible (→
`azure-development`). Avoid long-lived shared keys; rotate.
