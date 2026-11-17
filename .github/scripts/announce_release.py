"""Posts a Discord release announcement when the addon version changes.

Configuration comes from environment variables set by the workflow:
  ADDON_NAME, TOC_PATH, CHANGELOG_FILE, SITE_URL, ZIP_PATTERN, EMBED_COLOR
  BEFORE_SHA       commit before the push (empty on manual runs)
  FORCE            "true" to post even if the version did not change (manual runs; skips waiting for the site)
  DISCORD_WEBHOOK_URL  webhook to post to; if unset, prints the payload instead (dry run)
"""

import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

VERSION_LINE = re.compile(r"^##\s*Version:\s*(\S+)", re.MULTILINE)


def read_version(toc_text):
    match = VERSION_LINE.search(toc_text or "")
    return match.group(1).strip() if match else None


def previous_version(before_sha, toc_path):
    if not before_sha or set(before_sha) == {"0"}:
        return None
    result = subprocess.run(
        ["git", "show", f"{before_sha}:{toc_path}"],
        capture_output=True, text=True, encoding="utf-8",
    )
    return read_version(result.stdout) if result.returncode == 0 else None


def changelog_entry(changelog_html, version):
    pattern = re.compile(
        r'<span class="changelog-tag">v' + re.escape(version) + r"</span>(.*?)</li>",
        re.DOTALL,
    )
    match = pattern.search(changelog_html)
    if not match:
        return None
    text = re.sub(r"<[^>]+>", "", match.group(1))
    return " ".join(html.unescape(text).split())


def wait_for_site(changelog_page, version, attempts=20, delay=15):
    """Waits until the live changelog page shows this version (GitHub Pages deploys in parallel)."""
    marker = f'<span class="changelog-tag">v{version}</span>'
    for attempt in range(1, attempts + 1):
        try:
            url = f"{changelog_page}?v={version}&t={int(time.time())}"
            request = urllib.request.Request(url, headers={"User-Agent": "release-announcer"})
            with urllib.request.urlopen(request) as response:
                if marker in response.read().decode("utf-8", "replace"):
                    print(f"Live site shows v{version}.")
                    return
        except urllib.error.URLError:
            pass
        print(f"Waiting for the live site to show v{version} ({attempt}/{attempts})...")
        time.sleep(delay)
    print("Warning: live site not updated in time; posting anyway.")


def build_payload(name, version, entry, site_url, zip_pattern, color):
    changelog_url = site_url + "changelog.html#release-history"
    download_url = site_url + zip_pattern.format(version=version)
    description = entry or "See the changelog for details."
    description += f"\n\n[Download v{version}]({download_url}) • [Full changelog]({changelog_url})"
    return {
        "username": name,
        "embeds": [{
            "title": f"{name} v{version}",
            "url": site_url,
            "description": description,
            "color": color,
        }],
    }


def post(webhook, payload):
    request = urllib.request.Request(
        webhook,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "release-announcer"},
        method="POST",
    )
    with urllib.request.urlopen(request) as response:
        print(f"Posted to Discord (HTTP {response.status}).")


def main():
    env = os.environ
    name = env["ADDON_NAME"]
    toc_path = env["TOC_PATH"]
    site_url = env["SITE_URL"].rstrip("/") + "/"
    force = env.get("FORCE", "").lower() == "true"

    with open(toc_path, encoding="utf-8") as f:
        new_version = read_version(f.read())
    if not new_version:
        sys.exit(f"No '## Version:' line found in {toc_path}.")

    old_version = previous_version(env.get("BEFORE_SHA", ""), toc_path)
    print(f"Version: {old_version or '(none)'} -> {new_version}")
    if new_version == old_version and not force:
        print("Version unchanged; nothing to announce.")
        return

    entry = None
    if os.path.exists(env["CHANGELOG_FILE"]):
        with open(env["CHANGELOG_FILE"], encoding="utf-8") as f:
            entry = changelog_entry(f.read(), new_version)
    if not entry:
        print(f"Warning: no changelog entry found for v{new_version}.")

    payload = build_payload(
        name, new_version, entry, site_url,
        env.get("ZIP_PATTERN", "{version}.zip"), int(env.get("EMBED_COLOR", "0")),
    )

    webhook = env.get("DISCORD_WEBHOOK_URL", "")
    if webhook and not force:
        wait_for_site(site_url + "changelog.html", new_version)
    if not webhook:
        if env.get("GITHUB_ACTIONS") == "true":
            sys.exit("DISCORD_WEBHOOK_URL secret is not set.")
        print("Dry run (no webhook set). Payload:")
        print(json.dumps(payload, indent=2))
        return
    post(webhook, payload)


if __name__ == "__main__":
    main()
