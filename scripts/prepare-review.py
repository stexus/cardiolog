#!/usr/bin/env python3
"""Make the local browser/native screenshot evidence viewable over the preview server."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parent.parent
out=root/'mockup/review'
out.mkdir(exist_ok=True)
pairs=[('Timer library · saved templates','browser-timer-library.png','native-timer-library.png'),('Timer setup · pinned Start','browser-timer-setup.png','native-timer-setup.png'),('Cool blue · dark appearance','browser-timer-setup-dark.png','native-timer-setup-dark.png'),('Paused · light portrait','browser-paused-light-portrait.png','native-paused-light-portrait.png'),('Completed · light portrait','browser-completed-light-portrait.png','native-completed-light-portrait.png'),('Paused · dark landscape','browser-paused-dark-landscape.png','native-paused-dark-landscape.png')]
sections=[]
for title,browser,native in pairs:
    for name in [browser,native]:shutil.copyfile(root/'artifacts'/name,out/name)
    sections.append(f'<section><h2>{title}</h2><div class="pair"><figure><figcaption>Browser companion</figcaption><a href="{browser}"><img src="{browser}" alt="Browser: {title}"></a></figure><figure><figcaption>Native iOS 26.3 simulator</figcaption><a href="{native}"><img src="{native}" alt="Native: {title}"></a></figure></div></section>')
(out/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CardioLog · Milestone 1 evidence</title><style>body{font:16px/1.5 system-ui;background:#eaf0f9;color:#14243c;margin:30px auto;max-width:1400px;padding:0 20px}a{color:#1761d8}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0;background:white;padding:18px;border-radius:18px}figcaption{margin-bottom:15px}img{width:100%;max-height:760px;object-fit:contain}section{margin-top:35px}@media(max-width:700px){.pair{grid-template-columns:1fr}}</style><a href="/">← Interactive preview</a><h1>CardioLog · Milestone 1 review</h1><p>Matching shared fixtures in the browser companion and native SwiftUI shell. All sessions and HR are sample data. Native platform rendering differs; labels, timing, equipment and interval statistics should agree.</p><p>Simulator screenshots do not establish physical signing, Bluetooth, Health, background cue, or ring behavior. GitHub execution awaits the user’s remote.</p>'''+''.join(sections)+'</html>')
print('Screenshot review available at /review/')
