#!/usr/bin/env python3
"""Local document-review server for the orchestrate skill.

Serves a markdown plan as a reviewable HTML page; a human leaves anchored
comments and submits a verdict; the verdict is written to a JSON file that
an orchestrating agent polls. Python 3 stdlib only.
"""
import argparse
import json
import os
import signal
import socket
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# ---------------------------------------------------------------------------
# Markdown -> HTML (minimal, escapes all HTML in source first)
# ---------------------------------------------------------------------------

def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
             .replace('"', "&quot;"))


def inline(md: str) -> str:
    """Render inline markdown on an already-escaped string."""
    out = []
    i = 0
    n = len(md)
    while i < n:
        c = md[i]
        if c == "`":
            j = md.find("`", i + 1)
            if j == -1:
                out.append(c)
                i += 1
                continue
            out.append("<code>" + md[i + 1:j] + "</code>")
            i = j + 1
        elif c == "*":
            if i + 1 < n and md[i + 1] == "*":
                j = md.find("**", i + 2)
                if j == -1:
                    out.append(c)
                    i += 1
                    continue
                out.append("<strong>" + inline(md[i + 2:j]) + "</strong>")
                i = j + 2
            else:
                j = md.find("*", i + 1)
                if j == -1:
                    out.append(c)
                    i += 1
                    continue
                out.append("<em>" + inline(md[i + 1:j]) + "</em>")
                i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def is_separator_row(line: str) -> bool:
    t = line.strip()
    if not (t.startswith("|") and t.endswith("|")):
        return False
    cells = [c.strip() for c in t.strip("|").split("|")]
    return bool(cells) and all(c and set(c) <= set(":- ") and "-" in c for c in cells)


def split_row(line: str):
    t = line.strip()
    if t.startswith("|"):
        t = t[1:]
    if t.endswith("|"):
        t = t[:-1]
    return [c.strip() for c in t.split("|")]


def render_markdown(md_text: str) -> str:
    """Render markdown to HTML. Every top-level block gets data-block-id="bN"."""
    lines = md_text.splitlines()
    blocks = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            i += 1
            continue
        # fenced code block
        if stripped.startswith("```"):
            lang = esc(stripped[3:].strip())
            body = []
            i += 1
            while i < n and not lines[i].strip().startswith("```"):
                body.append(esc(lines[i]))
                i += 1
            i += 1  # skip closing fence
            cls = ' class="lang-%s"' % lang if lang else ""
            blocks.append("<pre%s><code>%s</code></pre>" % (cls, "\n".join(body)))
            continue
        # horizontal rule
        t = line.strip()
        if t and set(t) <= set("- *_") and (t.count("-") + t.count("*") + t.count("_")) >= 3:
            blocks.append("<hr>")
            i += 1
            continue
        # heading
        if stripped.startswith("#"):
            level = 0
            while level < len(stripped) and stripped[level] == "#":
                level += 1
            if 1 <= level <= 4 and level < len(stripped) and stripped[level] == " ":
                text = inline(esc(stripped[level + 1:]))
                blocks.append("<h%d>%s</h%d>" % (level, text, level))
                i += 1
                continue
        # blockquote (consume consecutive > lines)
        if stripped.startswith(">"):
            body = []
            while i < n and lines[i].strip().startswith(">"):
                body.append(lines[i].strip()[1:].lstrip())
                i += 1
            blocks.append("<blockquote>%s</blockquote>" % inline(esc(" ".join(body))))
            continue
        # table
        if stripped.startswith("|") and i + 1 < n and is_separator_row(lines[i + 1]):
            header = split_row(lines[i])
            rows = []
            i += 2
            while i < n and lines[i].strip().startswith("|"):
                rows.append(split_row(lines[i]))
                i += 1
            h = "".join("<th>%s</th>" % inline(esc(c)) for c in header)
            b = "".join(
                "<tr>%s</tr>" % "".join("<td>%s</td>" % inline(esc(c)) for c in r)
                for r in rows
            )
            blocks.append("<table><thead><tr>%s</tr></thead><tbody>%s</tbody></table>" % (h, b))
            continue
        # lists
        if stripped[0] in "-*" and (len(stripped) == 1 or stripped[1] == " "):
            items = []
            while i < n:
                s = lines[i].strip()
                if s[:1] in "-*" and (len(s) < 2 or s[1] == " "):
                    items.append(inline(esc(s[2:].strip())))
                    i += 1
                elif s and items and not lines[i].startswith((" ", "\t")):
                    break
                else:
                    items[-1] += " " + inline(esc(s))
                    i += 1
            blocks.append("<ul>%s</ul>" % "".join("<li>%s</li>" % it for it in items))
            continue
        if len(stripped) > 1 and stripped[0].isdigit() and stripped[1] in ".)" or (
            stripped[:1].isdigit() and stripped.split(" ", 1)[0][:-1].isdigit() if " " in stripped else False
        ):
            pass  # fallthrough handled below
        if stripped[:1].isdigit():
            first = stripped.split(" ", 1)
            if len(first) == 2 and first[0][:-1].isdigit() and first[0].endswith((".", ")")):
                items = []
                while i < n:
                    s = lines[i].strip()
                    f = s.split(" ", 1)
                    if len(f) == 2 and f[0][:-1].isdigit() and f[0].endswith((".", ")")):
                        items.append(inline(esc(f[1])))
                        i += 1
                    elif s and items and not lines[i].startswith((" ", "\t")):
                        break
                    else:
                        items[-1] += " " + inline(esc(s))
                        i += 1
                blocks.append("<ol>%s</ol>" % "".join("<li>%s</li>" % it for it in items))
                continue
        # paragraph (consecutive plain lines)
        para = [stripped]
        i += 1
        while i < n:
            s = lines[i].strip()
            if (not s or s.startswith(("#", ">", "```", "|")) or s[:1] in "-*"
                    or (s[:1].isdigit() and len(s.split(" ", 1)) == 2
                        and s.split(" ", 1)[0][:-1].isdigit()
                        and s.split(" ", 1)[0].endswith((".", ")")))):
                break
            if s and set(s) <= set("- *_") and (s.count("-") + s.count("*") + s.count("_")) >= 3:
                break
            para.append(s)
            i += 1
        blocks.append("<p>%s</p>" % inline(esc(" ".join(para))))
    return "\n".join(
        '<div class="blk" data-block-id="b%d">%s</div>' % (idx, b)
        for idx, b in enumerate(blocks)
    )


# ---------------------------------------------------------------------------
# HTML page
# ---------------------------------------------------------------------------

PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
<style>
:root {
  --bg: #ffffff; --fg: #1a1a1a; --muted: #6b7280; --border: #e5e7eb;
  --accent: #c2410c; --accent-bg: #fff7ed; --card: #f9fafb;
  --primary: #16a34a; --danger: #dc2626; --secondary: #4b5563;
  --flash: #fef08a;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #111418; --fg: #e5e7eb; --muted: #9ca3af; --border: #2a2f37;
    --accent: #fb923c; --accent-bg: #2a1d10; --card: #1a1f26;
    --primary: #22c55e; --danger: #ef4444; --secondary: #9ca3af;
    --flash: #713f12;
  }
}
* { box-sizing: border-box; }
body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
  Helvetica, Arial, sans-serif; background: var(--bg); color: var(--fg);
  line-height: 1.65; }
.layout { display: flex; min-height: 100vh; padding-bottom: 76px; }
main { flex: 1; padding: 48px 24px; min-width: 0; }
.doc { max-width: 760px; margin: 0 auto; }
.doc h1, .doc h2, .doc h3, .doc h4 { line-height: 1.3; margin: 1.4em 0 .5em; }
.doc h1:first-child { margin-top: 0; }
.doc p, .doc ul, .doc ol, .doc blockquote, .doc pre, .doc table { margin: .8em 0; }
.doc code { background: var(--card); border: 1px solid var(--border);
  border-radius: 4px; padding: .1em .35em; font-size: .9em; }
.doc pre { background: var(--card); border: 1px solid var(--border);
  border-radius: 8px; padding: 14px; overflow-x: auto; }
.doc pre code { background: none; border: none; padding: 0; }
.doc blockquote { border-left: 3px solid var(--accent); margin-left: 0;
  padding: .2em 1em; color: var(--muted); }
.doc table { border-collapse: collapse; width: 100%; }
.doc th, .doc td { border: 1px solid var(--border); padding: 6px 10px;
  text-align: left; }
.doc th { background: var(--card); }
.blk { position: relative; padding: 2px 44px 2px 4px; margin: 2px -44px 2px -4px;
  border-radius: 6px; }
.blk:hover { background: color-mix(in srgb, var(--accent) 6%, transparent); }
.bubble { position: absolute; right: 4px; top: 4px; opacity: 0; cursor: pointer;
  border: 1px solid var(--border); background: var(--bg); color: var(--accent);
  border-radius: 50%; width: 26px; height: 26px; line-height: 1; font-size: 14px;
  display: flex; align-items: center; justify-content: center; user-select: none; }
.blk:hover .bubble, .bubble.open { opacity: 1; }
.blk.flash { animation: flash 1.6s ease-out; }
@keyframes flash { 0%,60% { background: var(--flash); } 100% { background: transparent; } }
.blk.has-comment { border-left: 3px solid var(--accent); }
.composer { border: 1px solid var(--accent); border-radius: 8px; padding: 10px;
  margin: 6px 0 6px 8px; background: var(--accent-bg); }
.composer textarea { width: 100%; min-height: 70px; font: inherit; padding: 8px;
  border: 1px solid var(--border); border-radius: 6px; background: var(--bg);
  color: var(--fg); resize: vertical; }
.composer .row { margin-top: 8px; display: flex; gap: 8px; }
aside { width: 320px; flex-shrink: 0; border-left: 1px solid var(--border);
  padding: 24px 16px; background: var(--card); }
aside h2 { font-size: 15px; margin: 0 0 12px; color: var(--muted);
  text-transform: uppercase; letter-spacing: .04em; }
.cmt { border: 1px solid var(--border); background: var(--bg); border-radius: 8px;
  padding: 10px 12px; margin-bottom: 10px; font-size: 14px; }
.cmt .anchor { color: var(--muted); font-size: 12px; cursor: pointer;
  border-left: 3px solid var(--accent); padding-left: 6px; margin-bottom: 6px;
  display: block; }
.cmt .anchor:hover { text-decoration: underline; }
.cmt .text { color: var(--accent); }
.cmt .del { float: right; background: none; border: none; color: var(--muted);
  cursor: pointer; font-size: 13px; padding: 0; }
.cmt .del:hover { color: var(--danger); }
.empty { color: var(--muted); font-size: 14px; font-style: italic; }
footer { position: fixed; bottom: 0; left: 0; right: 0; display: flex;
  align-items: center; gap: 12px; padding: 12px 20px; background: var(--bg);
  border-top: 1px solid var(--border); box-shadow: 0 -2px 12px rgba(0,0,0,.06); }
footer .title { flex: 1; font-weight: 600; overflow: hidden; text-overflow: ellipsis;
  white-space: nowrap; }
button.act { border: none; border-radius: 8px; padding: 9px 18px; font-size: 14px;
  font-weight: 600; cursor: pointer; }
button.approve { background: var(--primary); color: #fff; }
button.reject { background: var(--danger); color: #fff; }
button.changes { background: transparent; color: var(--secondary);
  border: 1px solid var(--secondary); }
button.minor { border: 1px solid var(--border); background: var(--bg);
  color: var(--fg); border-radius: 6px; padding: 5px 10px; font-size: 13px;
  cursor: pointer; }
.err { color: var(--danger); margin: 12px 0; font-size: 14px; }
.done { max-width: 560px; margin: 120px auto; text-align: center; }
.done .big { font-size: 22px; margin-bottom: 8px; }
@media (max-width: 900px) {
  .layout { flex-direction: column-reverse; }
  aside { width: auto; border-left: none; border-top: 1px solid var(--border); }
  .blk { padding-right: 36px; }
}
</style>
</head>
<body>
<div class="layout">
<main><div class="doc" id="doc">
__BODY__
</div></main>
<aside>
  <h2>Comments (<span id="ccount">0</span>)</h2>
  <div id="clist"><p class="empty">No comments yet. Hover a paragraph and click the &plus; bubble.</p></div>
</aside>
</div>
<footer>
  <span class="title">__TITLE__</span>
  <div class="err" id="err" style="display:none;flex:0"></div>
  <button class="act changes" onclick="submitV('changes_requested')">Request changes</button>
  <button class="act reject" onclick="confirmSubmit('rejected')">Reject</button>
  <button class="act approve" onclick="confirmSubmit('approved')">Approve</button>
</footer>
<script>
var comments = [];
function $(id) { return document.getElementById(id); }
function esc(s) { return s.replace(/&/g,"&amp;").replace(/</g,"&lt;")
  .replace(/>/g,"&gt;").replace(/"/g,"&quot;"); }
document.querySelectorAll('.blk').forEach(function (blk) {
  var b = document.createElement('div');
  b.className = 'bubble'; b.textContent = '+';
  b.title = 'Comment on this block';
  b.onclick = function (ev) { ev.stopPropagation(); openComposer(blk); };
  blk.appendChild(b);
});
function closeComposer() {
  var c = document.querySelector('.composer');
  if (c) { c.previousElementSibling.classList.remove('flash'); c.remove(); }
}
function openComposer(blk) {
  closeComposer();
  blk.classList.add('flash');
  var c = document.createElement('div');
  c.className = 'composer';
  c.innerHTML = '<textarea placeholder="Leave a comment&hellip;"></textarea>' +
    '<div class="row"><button class="minor" data-a="add">Add comment</button>' +
    '<button class="minor" data-a="cancel">Cancel</button></div>';
  blk.insertAdjacentElement('afterend', c);
  var ta = c.querySelector('textarea');
  ta.focus();
  c.querySelector('[data-a=cancel]').onclick = function () {
    blk.classList.remove('flash'); c.remove();
  };
  c.querySelector('[data-a=add]').onclick = function () {
    var text = ta.value.trim();
    if (!text) { ta.focus(); return; }
    var bclone = blk.cloneNode(true);
    var bb = bclone.querySelector('.bubble');
    if (bb) bb.remove();
    comments.push({
      block_id: blk.getAttribute('data-block-id'),
      block_text: bclone.textContent.trim().slice(0, 4000),
      comment: text
    });
    blk.classList.add('has-comment');
    blk.classList.remove('flash');
    c.remove();
    renderComments();
  };
}
function renderComments() {
  $('ccount').textContent = comments.length;
  var list = $('clist');
  list.innerHTML = '';
  if (!comments.length) {
    list.innerHTML = '<p class="empty">No comments yet. Hover a paragraph and click the &plus; bubble.</p>';
    return;
  }
  comments.forEach(function (cm, i) {
    var d = document.createElement('div');
    d.className = 'cmt';
    var anchor = cm.block_text.slice(0, 80) + (cm.block_text.length > 80 ? '\u2026' : '');
    d.innerHTML = '<button class="del" title="Delete comment">&times;</button>' +
      '<span class="anchor">' + esc(anchor) + '</span>' +
      '<div class="text"></div>';
    d.querySelector('.text').textContent = cm.comment;
    d.querySelector('.del').onclick = function () {
      comments.splice(i, 1); renderComments();
      var blk = document.querySelector('[data-block-id="' + cm.block_id + '"]');
      if (blk) blk.classList.remove('has-comment');
    };
    d.querySelector('.anchor').onclick = function () {
      var blk = document.querySelector('[data-block-id="' + cm.block_id + '"]');
      if (blk) {
        blk.scrollIntoView({ behavior: 'smooth', block: 'center' });
        blk.classList.remove('flash'); void blk.offsetWidth; blk.classList.add('flash');
      }
    };
    list.appendChild(d);
  });
}
function confirmSubmit(v) {
  if (confirm('Submit verdict? Comments will be included.')) submitV(v);
}
function submitV(v) {
  closeComposer();
  fetch('/submit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ verdict: v, comments: comments })
  }).then(function (r) {
    if (r.ok) {
      document.body.innerHTML = '<div class="done"><div class="big">\u2713 Verdict recorded</div>' +
        '<p>You can close this tab.</p></div>';
      return;
    }
    return r.text().then(function (t) { throw new Error(t || ('HTTP ' + r.status)); });
  }).catch(function (e) {
    var el = $('err');
    el.style.display = 'inline'; el.textContent = 'Error: ' + e.message;
  });
}
</script>
</body>
</html>
"""


def build_page(md_text: str, title: str) -> str:
    body = render_markdown(md_text)
    t = esc(title)
    return PAGE.replace("__BODY__", body).replace("__TITLE__", t)


def first_heading(md_text: str, fallback: str) -> str:
    for line in md_text.splitlines():
        s = line.strip()
        if s.startswith("# "):
            return s[2:].strip()
    return fallback


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

class Handler(BaseHTTPRequestHandler):
    doc_html = ""
    out_path = ""
    submitted = False

    def log_message(self, *a):  # quiet
        pass

    def do_GET(self):
        if self.path != "/":
            self.send_error(404)
            return
        body = self.doc_html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/submit":
            self.send_error(404)
            return
        if Handler.submitted:
            self._text(410, "A verdict has already been submitted.")
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(length).decode("utf-8"))
            verdict = data["verdict"]
            if verdict not in ("approved", "changes_requested", "rejected"):
                raise ValueError("bad verdict")
            comments = []
            for c in data.get("comments", []):
                comments.append({
                    "block_id": str(c["block_id"]),
                    "block_text": str(c.get("block_text", "")),
                    "comment": str(c["comment"]),
                })
            payload = {"verdict": verdict, "comments": comments}
        except Exception as e:
            self._text(400, "Invalid submission: %s" % e)
            return
        atomic_write(self.out_path, json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
        Handler.submitted = True
        self._text(200, "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
                        "<title>Verdict recorded</title></head><body style=\""
                        "font-family:-apple-system,sans-serif;text-align:center;"
                        "margin-top:15vh\"><h1>Verdict recorded</h1>"
                        "<p>You can close this tab.</p></body></html>",
                   content_type="text/html; charset=utf-8")

    def _text(self, code, msg, content_type="text/plain; charset=utf-8"):
        body = msg.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def atomic_write(path: str, content: str):
    d = os.path.dirname(os.path.abspath(path)) or "."
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".review-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def pick_port(preferred: int) -> int:
    if preferred == 0:
        s = socket.socket()
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
        s.close()
        return port
    for p in range(preferred, preferred + 200):
        s = socket.socket()
        try:
            s.bind(("127.0.0.1", p))
        except OSError:
            continue
        finally:
            s.close()
        return p
    raise SystemExit("No free port found starting at %d" % preferred)


def main():
    ap = argparse.ArgumentParser(description="Local markdown review server")
    ap.add_argument("--doc", required=True, help="absolute path to markdown doc")
    ap.add_argument("--out", required=True, help="absolute path for verdict JSON")
    ap.add_argument("--ready", default=None, help="file to write the ready URL to")
    ap.add_argument("--port", type=int, default=7999,
                    help="port to listen on (default 7999; 0 = ephemeral)")
    args = ap.parse_args()

    with open(args.doc, encoding="utf-8") as f:
        md_text = f.read()
    title = first_heading(md_text, os.path.basename(args.doc))
    Handler.doc_html = build_page(md_text, title)
    Handler.out_path = os.path.abspath(args.out)

    port = pick_port(args.port)
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = "http://127.0.0.1:%d/" % server.server_address[1]
    print(url, flush=True)
    if args.ready:
        atomic_write(os.path.abspath(args.ready), url + "\n")

    def shutdown(signum, frame):
        server.shutdown()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
