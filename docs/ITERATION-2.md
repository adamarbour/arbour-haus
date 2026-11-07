# Iteration 2: Home Assistant, MQTT, Zigbee, and Z-Wave

## Status and scope

Adam requested this next iteration after initial installation, SSH access,
and Tailscale enrollment. This is an implementation plan, **not an enabled or
runtime-verified feature**. The current configuration still leaves Home
Assistant disabled. Do not add partially configured services or guess hardware
settings to make evaluation pass.

In scope:

- Home Assistant using the ordinary NixOS service (no Supervisor/add-on store).
- Mosquitto as the MQTT broker for Home Assistant and Zigbee2MQTT.
- Zigbee2MQTT connecting to the PoE Zigbee coordinator over the LAN.
- Z-Wave JS connecting to the PoE Z-Wave controller over the LAN, with Home
  Assistant using its native Z-Wave JS WebSocket integration.
- Narrow persistence, runtime secrets, backups, tests, and an operator-run
  deployment/acceptance procedure for all four services.

Matter, Thread, border routers, and GitHub deployment automation are deferred.
Do not enable them, open speculative ports, or change dependency pins/disk
layout/stateVersion as part of this iteration. The paused GitHub work resumes
at [GITHUB_DEPLOYMENT.md](GITHUB_DEPLOYMENT.md#paused-work-resume-github-deployment-here).
All implementation changes still use Adam-reviewed PRs.

## Intended topology

```text
PoE Zigbee coordinator <-- LAN radio transport --> Zigbee2MQTT
                                                       |
                                                      MQTT
                                                       |
                                                   Mosquitto
                                                       |
                                                      MQTT
                                                       |
                                                Home Assistant
                                                       |
                                             Z-Wave JS WebSocket
                                                       |
                                                   Z-Wave JS
                                                       |
                                              LAN radio transport
                                                       |
                                               PoE Z-Wave controller
```

Z-Wave JS does not need MQTT for this design. Do not enable an additional
Z-Wave MQTT bridge by default. Choose between the pinned native Z-Wave JS
service and Z-Wave JS UI only after checking radio compatibility and any
requirements for its management UI. Home Assistant must not also run ZHA
against the Zigbee2MQTT coordinator. Each radio has exactly one active owner;
stop previous clients before migration or testing a replacement instance.

PoE supplies power; it does not establish whether an adapter exposes raw TCP
serial, a vendor WebSocket API, or another transport. Never assume a port,
serial adapter driver, baud rate, flow control setting, or Z-Wave region from
"PoE" alone. These links are often unauthenticated/unencrypted: keep them on a
trusted LAN/IoT VLAN with only the required host-to-radio access and no WAN
forwarding. Tailscale admin access does not itself secure these LAN links.

## Operator-supplied hardware inventory

Adam supplied the following inventory and authorized using these addresses as
provisional planning values, in the order listed. They are not verified DHCP
reservations or reachable endpoints, and no service ports are known yet.

| Role | Operator-reported hardware | Provisional LAN IP | Network status |
| --- | --- | --- | --- |
| Zigbee coordinator | SONOFF Dongle Max Zigbee/Thread PoE; exact model identifier and firmware still to confirm | `10.10.10.11` | Fresh network |
| Z-Wave controller | SONOFF Z-Wave 800 PoE Dongle Max, `Dongle-MZG23` | `10.10.10.12` | Fresh network |

Adam is US-based and was unsure of the configured Z-Wave region. Plan for the
**US regional setting**, subject to confirmation of the controller's supported
region and pinned driver's setting before activation. Do not infer or enable
US Long Range from location or the "800" name alone. Verify the model labels,
firmware, transport, and region against device settings/vendor documentation;
the inventory above is operator-reported, not a hardware compatibility test.

The Zigbee/Thread adapter will be used for **Zigbee only** in iteration 2.
Thread capability does not change the deferred Matter/Thread scope; do not
assume concurrent Zigbee and Thread operation or flash firmware automatically.
Both networks are fresh, so no existing pairings need migrating. Fresh does
not grant permission to reset/flash radios or generate security identities
without an agreed provisioning step. Once established, preserve all keys and
network identity across rebuilds and reboots.

## Operator fill-in worksheet

Adam requested placeholders for the remaining radio settings. Fill in this
worksheet from each adapter's label and settings/vendor instructions before
turning it into production configuration. `FILL_IN` is deliberately not a
working setting; do not infer defaults or deploy these placeholders.

| Setting | Zigbee adapter | Z-Wave adapter |
| --- | --- | --- |
| LAN IP (provisional; confirm reservation) | `10.10.10.11` | `10.10.10.12` |
| Exact model identifier (verify label) | `FILL_IN` | `Dongle-MZG23` (operator-reported; verify) |
| Network/bridge firmware version | `FILL_IN` | `FILL_IN` |
| Radio firmware version | `FILL_IN` | `FILL_IN` |
| Operating mode | `FILL_IN` (Zigbee coordinator, not Thread) | `FILL_IN` (controller/network serial mode) |
| Network serial transport/protocol | `FILL_IN` | `FILL_IN` |
| Network serial port | `FILL_IN` | `FILL_IN` |
| Driver/adapter type required by client | `FILL_IN` | `FILL_IN` |
| Baud rate / flow control (if applicable) | `FILL_IN` | `FILL_IN` |
| Supported/configured Z-Wave region | Not applicable | `FILL_IN` (US intended; verify support) |

If a field does not apply, record that explicitly rather than guessing a value.
Do not put credentials or network security keys in this worksheet.

## Confirmed Home Assistant access

Adam confirmed that Home Assistant must be reachable through **both the LAN
and Tailscale**. Plan authenticated UI/API access on TCP 8123 via the host's
LAN address and its Tailscale address. This decision applies to Home Assistant
only, not MQTT, Z-Wave JS WebSocket, or radio/management endpoints. No public
Internet exposure, router port forwarding, Tailscale Serve/Funnel, or reverse
proxy is requested.

Before activation, select the concrete LAN interface/source-subnet policy
from the target's actual network settings; the radio IPs do not establish the
host interface name or subnet mask. Restrict tailnet access to intended users
through grants/ACLs. Do not broadly trust either interface. Verify login and
connectivity over both paths and rejection from unauthorized tailnet clients.
This is a documented requirement, not a firewall change already applied.

## Remaining provisioning before implementation

Complete the radio worksheet and confirm the provisional addresses. Do not
treat an adapter's web management port as its serial endpoint. Check that arbour-haus can route to the radio addresses and
that VLAN/firewall policy permits only the required transport. No port scans,
radio connection attempts, firmware updates, or region changes have been run.

Also confirm:

- Whether Z-Wave Long Range is wanted and supported. Ordinary US Z-Wave is
  the proposed initial scope; a region change must be explicitly reviewed.
- An off-host backup destination/retention policy and whether the SOPS operator
  identity/host recipient setup in `secrets/README.md` is complete.

Only share nonsecret inventory here. Do not paste passwords, Zigbee network
keys, Z-Wave S0/S2 keys, Home Assistant tokens, or private identities into chat.
Provision required secrets through SOPS after identifying the consumers and
runtime file format; do not invent production values or commit test keys.

## Implementation requirements

### Modules and integration

Use explicit ordinary modules imported by
`hosts/arbour-haus/configuration.nix`; reuse the existing pinned sources.
Check the pinned NixOS modules/package versions before choosing settings.
Keep operator hardware endpoints distinct from isolated, nonfunctional test
fixtures. Missing required real settings must fail clearly, not silently run
against example addresses.

Enable the Home Assistant MQTT integration for Zigbee discovery and the native
Z-Wave JS integration. Document declarative versus UI-owned configuration so
regenerating Nix settings cannot overwrite onboarded users/integrations. Start
with Home Assistant's default SQLite recorder unless requirements justify
another stateful database. Bound recorder retention; do not add a database
server as an unrelated abstraction.

### Persistence and backups

Before enabling each service, verify its actual pinned state directory and
service identity and declare exact ownership/mode in that module's narrow
`environment.persistence."/persist"` entries. Document the concrete paths in
README and deployment docs alongside the implementation. Do not persist whole
`/var`, `/etc`, homes, or writable generated configuration in the Nix store.

The inventory must include:

| Service | State to preserve and back up securely |
| --- | --- |
| Home Assistant | Configuration, `.storage` users/tokens/integrations, dashboards/automations, recorder database |
| Mosquitto | Persistence database, retained discovery/messages, persistent subscriptions and queued messages |
| Zigbee2MQTT | Device database, coordinator backup where supported, network identity/configuration and keys |
| Z-Wave JS | Driver cache, inclusion/security material, controller/NVM backups where supported |

Runtime credentials and generated state may be plaintext on the unencrypted
persistent disk; restrict access and encrypt off-host backups. SOPS encrypts
repository payloads, not all live application state. Persisted state is not a
backup. Document a consistent snapshot/service-stop backup and restore process;
SQLite's WAL must not be lost through an unsafe live file copy. Back up before
first activation/migration and validate restore on an isolated instance that
cannot connect to production radios.

Controller NVM and host application state are separate: back up both when
supported. Generation rollback does not reverse database schemas, paired
networks, firmware, controller state, or device inclusions.

### Secrets and ordering

Use authenticated MQTT with distinct runtime identities and least-privilege
topic ACLs for Home Assistant and Zigbee2MQTT; do not enable anonymous LAN
access. Prefer a loopback-only broker because both consumers are local. Keep
Z-Wave JS WebSocket and any Zigbee2MQTT/Z-Wave management UI local-only by
default; use an SSH tunnel for administration where appropriate.

If creating network security keys, provision them once through an approved
secure process and back them up; never regenerate them on rebuild/reboot.
Use SOPS-encrypted payloads in `secrets/` and runtime paths appropriate to each
consumer. Add explicit service ordering/readiness dependencies where needed;
never `builtins.readFile` plaintext secret material into a derivation. Do not
log rendered configuration or key values during checks or diagnostics.

### Network and access

Expose Home Assistant's authenticated UI/API on TCP 8123 over both LAN and
Tailscale, with the explicit interface/source and tailnet policies described
above. Do not broadly trust `tailscale0` or open MQTT,
radio serial transports, management UIs, or WebSockets to all interfaces merely
to make discovery work. Test the resulting policy rather than assuming
Tailscale enrollment provides access control. MQTT and Z-Wave JS can use
explicit local integration endpoints without multicast discovery.

### Validation and acceptance

- Extend isolated evaluation checks to cover enabled services, radio endpoints,
  persistence ownership/modes, network boundaries, and secret startup ordering.
  Replace existing no-Home-Assistant/no-secret assertions with meaningful new
  coverage when implementation actually enables them, not before.
- Format handwritten Nix, run `./scripts/check.sh --deployment`, and build real
  settings using `./scripts/build.sh`. A fixture/mock cannot establish radio
  compatibility or yield a production candidate.
- Add service-level/VM checks where feasible without hardware. Verify broker
  authentication/ACLs, rejected unauthorized connections, local integration
  connectivity, and service restart behavior without printing secrets.
- Deploy only with permission. Confirm Home Assistant onboarding/login, MQTT
  discovery, coordinator/controller connection, and a representative device
  event/control for each radio. Pair/exclude/reset devices only with permission.
- Perform the authorized reboot/persistence acceptance in `DEPLOYMENT.md`:
  verify users, integrations, automations, paired devices, MQTT state, network
  keys, and both radio connections survive. Confirm LAN and Tailscale recovery
  access and exercise backup/restore before calling the iteration verified.

## Next action

Complete the radio worksheet and secret/backup provisioning requirements above;
do not ask Adam again whether these are fresh networks or whether Home Assistant
should be reachable over LAN and Tailscale. Then implement
a complete, coherent configuration and its tests/docs on a feature
branch. No production services, ports, secrets, or identities are changed by
this planning document.
