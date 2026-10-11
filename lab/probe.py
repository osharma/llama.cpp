#!/usr/bin/env python3
# Send a fixed set of chat requests to a test llama-server and print the
# server's own timings, to see what the prompt cache and speculative decoding
# do. Stdlib only (the Mac has Python 3.8).
#
# Usage: python3 lab/probe.py <port> cache|gen <document.txt>
#   cache: same long document with different questions, to see how much of
#          the prompt the server has to process again each time
#   gen:   longer answers, to compare generation speed (and drafts accepted)

import hashlib
import json
import sys
import time
import urllib.request

PORT, MODE, DOC = sys.argv[1], sys.argv[2], open(sys.argv[3]).read()
URL = "http://127.0.0.1:%s/v1/chat/completions" % PORT


def ask(messages, max_tokens):
    body = {
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 0,  # greedy: same answer every run, comparable outputs
        "chat_template_kwargs": {"enable_thinking": False},  # like production
    }
    req = urllib.request.Request(URL, json.dumps(body).encode(), {"Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=1800) as r:
        res = json.load(r)
    return res["choices"][0]["message"]["content"], res.get("timings", {}), time.time() - t0


def show(label, answer, t, wall):
    print("%-26s prompt %5d tok %7.1f s | gen %4d tok %5.2f tok/s | draft %s/%s | wall %6.1f s | %r"
          % (label, t.get("prompt_n", -1), t.get("prompt_ms", 0) / 1000,
             t.get("predicted_n", -1), t.get("predicted_per_second", 0),
             t.get("draft_n_accepted", "-"), t.get("draft_n", "-"), wall, answer[:60]))


system = {"role": "system", "content": "Answer using this document.\n\n" + DOC}

if MODE == "cache":
    q1 = {"role": "user", "content": "In one sentence: what is this document about?"}
    q2 = {"role": "user", "content": "In one sentence: which build options does it mention?"}
    a1, t, w = ask([system, q1], 32); show("1 doc+Q1 (cold)", a1, t, w)
    a, t, w = ask([system, q1], 32);  show("2 doc+Q1 (identical)", a, t, w)
    a, t, w = ask([system, q2], 32);  show("3 doc+Q2 (new question)", a, t, w)
    follow = [system, q1, {"role": "assistant", "content": a1},
              {"role": "user", "content": "And who is it for?"}]
    a, t, w = ask(follow, 32);        show("4 doc+Q1+A1+Q3 (chat)", a, t, w)
    a, t, w = ask([system, q1], 32);  show("5 doc+Q1 (back to Q1)", a, t, w)
elif MODE == "gen":
    tasks = [
        ("summary", "Summarize the document in about 150 words."),
        ("list", "List every build option or flag the document mentions, one per line, with a short note each."),
        ("quote", "Copy the first three paragraphs of the document exactly."),
    ]
    for label, text in tasks:
        a, t, w = ask([system, {"role": "user", "content": text}], 200)
        show(label, a, t, w)
        print("   answer md5:", hashlib.md5(a.encode()).hexdigest()[:12])
