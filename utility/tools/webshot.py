#!/usr/bin/env python3
"""
webshot.py - screenshot a URL with headless Chrome and composite the result
into a browser window frame drawn with Pillow, so the screenshot itself shows
which URL / port the page was actually served from.

Usage:
    python3 webshot.py <url> <out.png> [tab-title] [width] [height] [wait-ms]
    python3 webshot.py http://localhost:9090/targets screenshots/session-20/targets.png "Prometheus"
    WEBSHOT_WAIT_TEXT="Healthy" python3 webshot.py <url> <out.png>   # wait for text (SPAs)
"""
import base64
import json
import os
import shutil
import subprocess
import time
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

# Chrome refuses to write into dot-directories under a snap confinement, so the
# raw capture is always staged in a plain directory.
STAGE = os.path.expanduser("~/shots")

UI_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
UI_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

TABSTRIP_BG = (0xDE, 0xE1, 0xE6)
TAB_BG = (0xFF, 0xFF, 0xFF)
TOOLBAR_BG = (0xFF, 0xFF, 0xFF)
URLBAR_BG = (0xF1, 0xF3, 0xF4)
TEXT = (0x3C, 0x40, 0x43)
MUTED = (0x5F, 0x63, 0x68)
BORDER = (0xC6, 0xC9, 0xCD)

TABSTRIP_H = 40
TOOLBAR_H = 48


def capture(url, width, height, wait_ms):
    os.makedirs(STAGE, exist_ok=True)
    fd, raw = tempfile.mkstemp(suffix=".png", dir=STAGE)
    os.close(fd)
    profile = tempfile.mkdtemp(dir=STAGE, prefix="prof_")
    cmd = [
        "google-chrome", "--headless=new", "--disable-gpu", "--no-sandbox",
        "--hide-scrollbars", "--force-device-scale-factor=1",
        "--ignore-certificate-errors",
        f"--user-data-dir={profile}",
        # pages that keep a stream open (Argo CD's SSE watches) never let virtual
        # time advance; a negative wait means "real time": Chrome's --timeout
        (f"--virtual-time-budget={wait_ms}" if wait_ms > 0 else f"--timeout={-wait_ms}"),
        f"--window-size={width},{height}",
        f"--screenshot={raw}", url,
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=120)
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    return raw


def capture_when_text(url, width, height, wait_text, timeout=60):
    """Drive Chrome over the DevTools protocol (fd 3/4 pipe, stdlib only) and
    take the screenshot only once `wait_text` is visible on the page - needed
    for single-page apps that keep streaming (Argo CD) where a fixed wait
    either fires too early or never ends."""
    os.makedirs(STAGE, exist_ok=True)
    profile = tempfile.mkdtemp(dir=STAGE, prefix="prof_")
    to_chrome_r, to_chrome_w = os.pipe()
    from_chrome_r, from_chrome_w = os.pipe()

    def child_fds():
        # move both ends out of the way first: os.pipe() may itself have
        # returned 3 or 4, and a direct dup2 would then clobber the other end
        a, b = os.dup(to_chrome_r) + 100, os.dup(from_chrome_w) + 100
        os.dup2(to_chrome_r, a)
        os.dup2(from_chrome_w, b)
        os.dup2(a, 3)
        os.dup2(b, 4)

    proc = subprocess.Popen(
        ["google-chrome", "--headless=new", "--disable-gpu", "--no-sandbox",
         "--hide-scrollbars", "--force-device-scale-factor=1",
         f"--user-data-dir={profile}", f"--window-size={width},{height}",
         "--remote-debugging-pipe", "about:blank"],
        close_fds=False, preexec_fn=child_fds,   # keep the dup2-ed fds 3 and 4
        stdout=subprocess.DEVNULL, stderr=open(os.path.join(STAGE, "chrome-cdp.log"), "wb"))
    os.close(to_chrome_r)
    os.close(from_chrome_w)
    reader = os.fdopen(from_chrome_r, "rb")
    buf = b""
    msg_id = 0

    def call(method, params=None, session=None):
        nonlocal buf, msg_id
        msg_id += 1
        msg = {"id": msg_id, "method": method, "params": params or {}}
        if session:
            msg["sessionId"] = session
        os.write(to_chrome_w, json.dumps(msg).encode() + b"\0")
        while True:
            while b"\0" not in buf:
                chunk = reader.read1(65536)
                if not chunk:
                    raise RuntimeError("chrome closed the pipe")
                buf += chunk
            raw, buf = buf.split(b"\0", 1)
            reply = json.loads(raw)
            if reply.get("id") == msg_id:
                if "error" in reply:
                    raise RuntimeError(reply["error"])
                return reply["result"]

    try:
        target = call("Target.createTarget", {"url": url})["targetId"]
        session = call("Target.attachToTarget", {"targetId": target, "flatten": True})["sessionId"]
        call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height,
             "deviceScaleFactor": 1, "mobile": False}, session)
        deadline = time.time() + timeout
        probe = f"document.body && document.body.innerText.includes({json.dumps(wait_text)})"
        while True:
            found = call("Runtime.evaluate", {"expression": probe, "returnByValue": True}, session)
            if found["result"].get("value"):
                break
            if time.time() > deadline:
                raise RuntimeError(f"text {wait_text!r} never appeared on {url}")
            time.sleep(0.5)
        time.sleep(1.5)                      # let charts/graphs finish animating
        png = call("Page.captureScreenshot", {"format": "png"}, session)["data"]
        fd, raw_path = tempfile.mkstemp(suffix=".png", dir=STAGE)
        with os.fdopen(fd, "wb") as fh:
            fh.write(base64.b64decode(png))
        try:
            call("Browser.close")
        except RuntimeError:
            pass
        return raw_path
    finally:
        proc.wait(timeout=30) if proc.poll() is None and not proc.kill() else None
        shutil.rmtree(profile, ignore_errors=True)


def arrow(d, cx, cy, direction, colour):
    s = 5
    if direction == "left":
        d.line((cx + s, cy - s, cx - s, cy), fill=colour, width=2)
        d.line((cx - s, cy, cx + s, cy + s), fill=colour, width=2)
        d.line((cx - s, cy, cx + s + 2, cy), fill=colour, width=2)
    else:
        d.line((cx - s, cy - s, cx + s, cy), fill=colour, width=2)
        d.line((cx + s, cy, cx - s, cy + s), fill=colour, width=2)
        d.line((cx - s - 2, cy, cx + s, cy), fill=colour, width=2)


def frame(raw_png, out_png, url, tab_title):
    page = Image.open(raw_png).convert("RGB")
    pw, ph = page.size
    W = pw
    H = TABSTRIP_H + TOOLBAR_H + ph

    img = Image.new("RGB", (W, H), TABSTRIP_BG)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(UI_FONT, 13)
    fb = ImageFont.truetype(UI_BOLD, 13)

    # ---- tab strip with one active tab
    d.rectangle((0, 0, W, TABSTRIP_H), fill=TABSTRIP_BG)
    d.rounded_rectangle((8, 6, 268, TABSTRIP_H + 8), 8, fill=TAB_BG)
    d.ellipse((22, 16, 34, 28), fill=(0x1A, 0x73, 0xE8))
    title = tab_title if len(tab_title) <= 26 else tab_title[:25] + "…"
    d.text((44, 15), title, font=f, fill=TEXT)
    d.text((246, 14), "×", font=f, fill=MUTED)
    d.text((286, 13), "+", font=fb, fill=MUTED)

    # ---- toolbar
    ty = TABSTRIP_H
    d.rectangle((0, ty, W, ty + TOOLBAR_H), fill=TOOLBAR_BG)
    mid = ty + TOOLBAR_H // 2
    arrow(d, 24, mid, "left", MUTED)
    arrow(d, 56, mid, "right", (0xBD, 0xC1, 0xC6))
    d.arc((80, mid - 8, 96, mid + 8), 40, 330, fill=MUTED, width=2)
    d.polygon([(96, mid - 10), (96, mid - 1), (88, mid - 6)], fill=MUTED)

    # ---- url pill
    d.rounded_rectangle((116, mid - 15, W - 52, mid + 15), 15, fill=URLBAR_BG)
    d.rounded_rectangle((133, mid - 6, 141, mid + 5), 2, outline=MUTED, width=1)
    d.arc((133, mid - 11, 141, mid - 3), 180, 360, fill=MUTED, width=1)
    d.text((152, mid - 8), url, font=f, fill=TEXT)
    for i in range(3):                              # kebab menu
        d.ellipse((W - 32, mid - 8 + i * 6, W - 28, mid - 4 + i * 6), fill=MUTED)

    d.line((0, ty + TOOLBAR_H - 1, W, ty + TOOLBAR_H - 1), fill=BORDER)

    img.paste(page, (0, TABSTRIP_H + TOOLBAR_H))
    d.rectangle((0, 0, W - 1, H - 1), outline=BORDER)
    img.save(out_png)
    return out_png, W, H


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    url = sys.argv[1]
    out = sys.argv[2]
    tab = sys.argv[3] if len(sys.argv) > 3 else url
    width = int(sys.argv[4]) if len(sys.argv) > 4 else 1100
    height = int(sys.argv[5]) if len(sys.argv) > 5 else 620
    wait = int(sys.argv[6]) if len(sys.argv) > 6 else 4000

    wait_text = os.environ.get("WEBSHOT_WAIT_TEXT")
    raw = (capture_when_text(url, width, height, wait_text) if wait_text
           else capture(url, width, height, wait))
    path, w, h = frame(raw, out, url, tab)
    os.unlink(raw)
    print(f"{path}  {w}x{h}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
