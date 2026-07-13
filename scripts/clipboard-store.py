#!/usr/bin/env python3
"""Clipboard store filter for cliphist.

The watcher runs `wl-paste --type text`, where `text` is a GENERIC type name:
wl-paste picks "some offered MIME type that matches" it. When a page offers
text/plain, wl-paste picks that and everything is fine. But when it offers only
text/html -- copying an image, or rich content out of a contenteditable like
ChatGPT's ProseMirror editor -- text/html is the only match, so the raw markup
is what lands in the history:

    <meta http-equiv="content-type" content="text/html; charset=utf-8">the text

The panel strips tags for display, so the entry looks clean right up until you
paste it. Asking for text/plain instead would drop those entries entirely, which
is worse. So take whatever wl-paste gives us and strip the markup when it is
markup.

Detection is the meta prefix every browser prepends to a text/html payload, so
copied source code that merely happens to contain "<div>" is never touched.
Anything that is not that payload is forwarded byte for byte -- a trailing
newline is part of what you copied.
"""

import html
import re
import subprocess
import sys

# Every browser prepends this to a text/html clipboard payload.
HTML_PAYLOAD_PREFIX = b'<meta http-equiv="content-type" content="text/html'


def strip_browser_markup(markup: str) -> str:
    markup = re.sub(r"^<meta[^>]*>", "", markup, count=1)
    markup = re.sub(r"(?is)<(script|style)\b.*?</\1>", "", markup)

    # Block-level tags carry the line structure of the copied selection.
    markup = re.sub(r"(?i)<br\s*/?>", "\n", markup)
    markup = re.sub(r"(?i)</(p|div|li|tr|h[1-6]|blockquote|pre)>", "\n", markup)

    # An image alone carries no text: keep its source so the entry is not empty.
    markup = re.sub(
        r"(?i)<img[^>]*\bsrc=[\"']([^\"']+)[\"'][^>]*>", r"\1", markup
    )

    text = html.unescape(re.sub(r"<[^>]+>", "", markup))

    # Collapse the blank lines the block substitution leaves behind.
    text = re.sub(r"[ \t]+\n", "\n", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def main() -> int:
    payload = sys.stdin.buffer.read()

    if payload.startswith(HTML_PAYLOAD_PREFIX):
        text = strip_browser_markup(payload.decode("utf-8", "replace"))
        if not text:
            return 0
        payload = text.encode("utf-8")

    # --filter writes to stdout instead of storing. Entries captured before this
    # filter existed still hold markup, so copying one back out has to clean it
    # too, or the history stays poisoned for as long as those entries live.
    if "--filter" in sys.argv[1:]:
        sys.stdout.buffer.write(payload)
        return 0

    return subprocess.run(["cliphist", "store"], input=payload).returncode


if __name__ == "__main__":
    sys.exit(main())
