# ipsweep

A small, dependency-free Bash tool that discovers live hosts on a local `/24` subnet by
ICMP ping sweep. It detects your own IP (or takes one you type), pings every address in the
network, and prints the ones that respond. Runs on Linux, macOS, and Windows (Git Bash).

```
--------------------------------------------------------------
| IIIIII  PPPPPP   SSSSSSS w    W    W EEEEEEE EEEEEE PPPPPP |
|   II    P    P   S       w    W    W E       E      P    P |
|   II    P    P   S       W    W    W E       E      P    P |
|   II    PPPPP    SSSSSS  w    W    W EEEEEEE EEEEEE PPPPP  |
|   II    P             S  W    W    W E       E      P      |
|   II    P             S  W    W    W E       E      P      |
| IIIIII  P       SSSSSSS  WWWWWWWWWWW EEEEEEE EEEEEE P      |
|                                                 -by 1akin1 |
--------------------------------------------------------------
```

## Features

- Auto-detects your primary IPv4 address, or lets you enter one manually.
- Sweeps all 254 host addresses of the `/24` with a single ping each.
- True parallel scanning with a configurable concurrency limit (`wait -n` semaphore, with
  a fallback for older Bash).
- Cross-platform ping and IP detection: picks the right `ping` flags and IP lookup method
  for Linux, macOS/BSD, and Windows Git Bash.
- Strict IPv4 validation (rejects out-of-range octets; handles leading zeros correctly).
- Colored output, live results as hosts come up, and an optional saved results file.

## Requirements

- Bash 4.3 or newer for the `wait -n` concurrency control. Older Bash still works, but
  falls back to batch-style waiting (slightly slower under load).
- A working `ping`. On Windows it uses the built-in `ping.exe` through Git Bash.
- Standard utilities: `awk`, `grep`, `sort`, `seq`, `mktemp` (present on all target systems).

## Usage

```bash
bash ipsweep.sh [-h] [-o output_file] [-t timeout] [-j jobs]
```

| Flag | Meaning | Default |
|---|---|---|
| `-h` | Show help and exit | |
| `-o FILE` | Output file for the list of live hosts | `ip.txt` |
| `-t SECONDS` | Ping timeout per host (whole number) | `1` |
| `-j JOBS` | Maximum parallel pings | `50` |

Run it, then choose from the menu: auto-detect your IP, enter one manually, or quit. After a
network is chosen it asks for confirmation before scanning, and at the end it asks whether to
keep or delete the results file.

```bash
# Default scan, auto-detect the network
bash ipsweep.sh

# Faster sweep with a tighter timeout and more concurrency, saved to a custom file
bash ipsweep.sh -t 1 -j 100 -o hosts.txt
```

### Windows (Git Bash)

```bash
cd /c/Users/<you>/Desktop      # C:\ is /c/ in Git Bash
bash ipsweep.sh
```

If the script was edited on Windows and complains about `\r` or "command not found", convert
line endings to LF: `sed -i 's/\r$//' ipsweep.sh`.

## Output

Live hosts are printed as they respond and written to the output file, one per line, sorted
by the last octet:

```
Scanning 192.168.1.0/24 ...

  [+] 192.168.1.1 is UP
  [+] 192.168.1.103 is UP
  [+] 192.168.1.111 is UP

---------------------------------------------------
 Scan complete. 3 host(s) up on 192.168.1.0/24
---------------------------------------------------
```

## How it works

The script keeps OS-specific differences in two small functions:

- `ping_host` selects the correct single-ping invocation per platform. Linux uses `-W`
  (seconds), macOS/BSD use `-t` (seconds), and Windows `ping.exe` uses `-w` (milliseconds).
  On Windows it also checks the reply for `TTL=`, since `ping.exe` can exit successfully even
  on an unreachable reply.
- `detect_ip` finds the primary IPv4 per platform: `hostname -I` / routing table on Linux,
  `ipconfig getifaddr` / `ifconfig` on macOS, and PowerShell (`Get-NetIPConfiguration`) with
  an `ipconfig` fallback on Windows. Windows output has its trailing carriage return stripped.

Each ping runs in the background; a counter plus `wait -n` keeps at most `-j` pings in flight
at once. Each worker writes any hit to its own temp file, so parallel writes never collide;
the files are collated and sorted at the end, and the temp directory is removed on exit.

## Limitations

- ICMP only. A host that blocks incoming ping (for example a Windows machine with its
  firewall on, which drops echo requests by default) will show as down even when it is up.
  This reports hosts that answer ping, not necessarily every device on the network.
- IPv4 `/24` only. It sweeps `x.x.x.1` through `x.x.x.254` of the detected or entered network.
- Timeout is given in whole seconds.

## Notes on responsible use

Scan only networks you own or are authorized to test. Host discovery on networks you do not
control may violate the rules of that network or local policy.

## License

Released under the [MIT License](LICENSE).
