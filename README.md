# samsung-tv-deadt

Stops the advertising, content-recognition and telemetry daemons on a rooted Samsung Tizen TV.

Runtime only — a reboot puts everything back. That is a property of the TV, not a limitation of the script (see [Why this can't be permanent](#why-this-cant-be-permanent)).

Tested on a 2024 **TU65DU7105KXXC** running **Tizen 9.0.0** (`T-KSU2EDDEUC-0090-REL-202605141701`, kernel 5.4.249).

## Try this first — no root needed

Settings → All Settings → General & Privacy → **Terms & Privacy**:

- **Viewing Information Services** → off (this is the ACR/ambient-audio recognition)
- **Interest-Based Ads** / Samsung Ads personalization → off

That stops the data collection most people actually care about, and it survives reboots. Everything below is for the daemons that keep running and keep phoning home regardless.

## Requirements

Root. There is no public persistence, so you re-establish root after each reboot. The chain this was built against is [chris-ritsen/samsung-tv-root](https://github.com/chris-ritsen/samsung-tv-root) (`archive-root`), which needs **developer mode on** with the TV's `developerIP` set to your machine (Settings → Apps → App Settings → `12345` → Developer Mode → enter your IP → reboot).

Run `tv-deadt` as root. Over that toolkit:

```sh
cat tv-deadt.sh | <root-runner> --command "/bin/bash -s -- harden"
```

## Usage

```sh
tv-deadt status      # what's running
tv-deadt harden      # stop everything in the table below
tv-deadt harden --no-acr   # skip the content-recognition pair (keeps recommendations/guide working)
tv-deadt restore     # start back whatever harden stopped
```

State is written to `/opt/tv-deadt/state` so `restore` only restarts what it stopped. `/opt` is the one writable partition that survives a reboot.

## What gets stopped

| Group | Units | What it is |
|---|---|---|
| Advertising | `adagent-service`, `pisa-service` | PISA is Samsung's ad platform: bundled JS engine + ad auction client. Prefetched ad payloads land in `apps_rw/com.samsung.tv.pisa-service/data/adresponse/` |
| Advertising | `org.tizen.tv.tagpro-service-tv` | Ad measurement |
| Telemetry | `scs-agent`, `sp-kpi` | Samsung support agent, KPI reporting |
| Telemetry | `devicetracker`, `stability-monitor` | Device and stability reporting |
| Telemetry | `emergency-log-transmitter`, `issue_report_agent` | Log upload, issue reporting |
| Telemetry | `abnormal_user_behavior` | Behaviour scoring |
| ACR | `contents-recognition-service`, `csf-content-engine` | Automatic content recognition — what you watch |

Endpoints pulled out of the binaries:

- `adagent-service` → `https://rtb-config.samsungads.com/tvplus`, `https://rtb-config-canary.samsungads.com/tvplus`
- its bundled ad framework → `imasdk.googleapis.com` (Google IMA), `pagead2.googlesyndication.com/pagead/gen_204`

Stopping the ad stack does not disturb the TV: the REST API on `:8001` keeps answering and `systemctl --failed` stays at 0. `stop` also defeats `Restart=always` — an explicitly stopped unit does not get resurrected.

## Why this can't be permanent

Three things are in the way, all verified on the device:

1. **Root is volatile.** The escalation rides `sdbd` + developer mode; reboot clears it.
2. **The root filesystem is signed and read-only.** `/` and `/usr/lib/systemd/system` are `vdfs ro`, so `systemctl mask` fails outright: `File /etc/systemd/system/…: Read-only file system`.
3. **Code signing blocks substituted binaries.** `/opt` *is* writable, and many services execute from it — so replacing a daemon with a stub looks like the obvious move. It doesn't work. Copying the signed `/bin/true` over `adagent-service` (renamed into place to dodge `ETXTBSY`) and letting systemd restart it gives:

   ```
   Result=exit-code  ExecMainStatus=203   # 203 = exec failed
   ```

   Executables are signature-checked at their path. Same reason a script has to be fed through `cat file | bash` rather than executed.

So: no firmware mod, no stubs, no boot hook. Reapply after each reboot, or leave it and accept the reset.

## Not included

No exploit code. Root is a prerequisite and is someone else's work — see the toolkit linked above.

## License

MIT
