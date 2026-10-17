# downloads.csv: id, file, url — every file fetched into data-raw/raw/, from the
# folders' SOURCES.tsv / SOURCES.txt / URLS.txt notes.
import csv, os, re
raw = os.path.expanduser("~/System/Research/REM/data-raw/raw")
rows = []
for d in sorted(os.listdir(raw)):
    p = os.path.join(raw, d)
    if not os.path.isdir(p): continue
    for name in ("SOURCES.tsv", "SOURCES.txt", "URLS.txt"):
        f = os.path.join(p, name)
        if not os.path.exists(f): continue
        for line in open(f, errors="ignore"):
            line = line.strip()
            if not line or line.startswith("#") or line.startswith("accessed"): continue
            url = next((u for u in re.findall(r"https?://\S+", line)), None)
            if not url: continue
            parts = line.split("\t")
            fname = parts[1] if name == "SOURCES.tsv" and len(parts) >= 3 else (line.split("->")[-1].strip() if "->" in line else os.path.basename(url.split("?")[0]))
            rows.append((d, fname, url))
out = os.path.expanduser("~/System/Research/REM/vignettes/articles/data/catalogue/downloads.csv")
with open(out, "w", newline="") as fh:
    w = csv.writer(fh); w.writerow(["id", "file", "url"]); w.writerows(rows)
have = {r[0] for r in rows}
print(len(rows), "files from", len(have), "folders; folders without URL notes:",
      [d for d in sorted(os.listdir(raw)) if os.path.isdir(os.path.join(raw, d)) and d not in have])
