# Secrets

Store **only SOPS-encrypted payloads** here (for example `arbour-haus.yaml`).
Never commit plaintext secrets, age private keys, or SSH private keys. Public
recipients belong in `.sops.yaml`; private identities stay outside this repo.
No secret is required for the initial installation.

## First secret (after the host has booted)

On your trusted workstation, enter `nix-shell` in the repository. Create an
operator identity outside the repository and back it up securely. Do not keep
it in the server's ephemeral home directory:

```sh
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

Get the host's public recipient through your already verified SSH connection:

```sh
ssh admin@arbour-haus 'cat /etc/ssh/ssh_host_ed25519_key.pub' | ssh-to-age
```

Replace `.sops.yaml` with the following, substituting both actual public
recipients (these placeholders are intentionally not valid keys):

```yaml
keys:
  - &operator age1_OPERATOR_PUBLIC_RECIPIENT
  - &arbour_haus age1_HOST_PUBLIC_RECIPIENT
creation_rules:
  - path_regex: ^secrets/.*\.(yaml|json|env)$
    key_groups:
      - age:
          - *operator
          - *arbour_haus
```

From the repository root, create the encrypted file using SOPS, not a plaintext
editor followed by a commit:

```sh
sops secrets/arbour-haus.yaml
```

Add a key such as `example: value` in the SOPS editor. Then enable the commented
`defaultSopsFile` and `secrets.example` declarations in `modules/secrets.nix`.
Secret values stay encrypted on disk (SOPS metadata is public); sops-nix
decrypts at activation into `/run/secrets`. Configure consumers with `config.sops.secrets.example.path`,
never `builtins.readFile` (which can leak plaintext into the Nix store).

When recipients change, run `sops updatekeys secrets/arbour-haus.yaml`.
The host SSH identity is persisted under `/persist/etc/ssh` and exposed at
`/etc/ssh`; sops-nix reads its persistent backing path directly so it does not
depend on the ephemeral root's links being ready. It survives ordinary reboots.
Back it up securely: reinstalling without restoring it changes its recipient,
so use the operator identity to re-encrypt for the new host key. For secrets
needed on the *first* boot, provision the host identity out of band into
`/mnt/persist/etc/ssh` before activation, with private keys owned by root and
mode `0600`; this scaffold intentionally avoids that dependency. Decrypted
secrets in `/run/secrets` remain ephemeral and are recreated each boot.
