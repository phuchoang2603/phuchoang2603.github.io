---
title: "Automating Manga Translations: My Journey to a Seamless Reading Experience"
date: 2025-03-03
tags:
  - self-hosted
  - entertainment
description:
draft: false
featureimage: https://i.ibb.co/V0Hk9hPh/image.png
---
## Video demo:

{{< youtubeLite id="RgkC246Ul44" label="Video demo" >}}

---
## The Struggle: Why I Needed This

Have you ever stumbled upon a manga so niche and obscure that it never gets an official English release? That was me—desperately trying to read intimate and underrated series that weren’t even on MangaDex, likely due to copyright issues.

At first, I took the long road: hunting for raw Japanese scans, screenshotting pages, and running them through image translation tools. It worked... barely. The process was painfully slow and completely broke my immersion. Instead of enjoying the story, I spent more time waiting on awkward machine translations. It was, in a word, **disruptive**.

Then it hit me: I already had **Suwayomi**, a powerful manga server that supports multiple sources and local file management. Why not build my own translation pipeline?

---
## Finding a Better Way

My first attempt was to look for an existing solution. I found a closed-source iOS app that seemed promising, but when I saw their **$15/month paywall**, I immediately bailed. (In case you're curious, here's the [link](https://apps.apple.com/us/app/manga-translate/id6502868308).)

That led me to GitHub, where I stumbled upon [this amazing project](https://github.com/zyddnys/manga-image-translator). The demo results blew me away, and I knew I had to dive in and make it work for my setup.

---
## Prerequisite

To follow along, you’ll need Suwayomi Server installed. You can check out the official Docker setup here:  
[Suwayomi-Server-docker GitHub](https://github.com/Suwayomi/Suwayomi-Server-docker)

After installation, set up the download folder and local source location. Reference:  
[Suwayomi Local Source Wiki](https://github.com/Suwayomi/Suwayomi-Server/wiki/Local-Source)

Here’s my folder structure for Suwayomi:
```yaml
.
├── data #suwayomi folder
│   ├── downloads # default download folder
│   │   ├── mangas
│   │   │   └── Rawkuma (JA)
│   │   │       ├── Batsu Hare
│   │   │       │   ├── Chapter 100 ...
│   │   │       ├── Grapara!
│   │   │       │   ├── Chapter 69 ...
│   │   │       ├── Guilty Circle
│   │   │       │   ├── Chapter 1 ...
│   │   │       ├── Isekai Saikouhou no Guild Leader
│   │   │       │   ├── Chapter 1 ...
│   │   │       └── Spy X Family
│   │   │           ├── Chapter 105.5 ...
│   │   └── thumbnails
│   ├── translated # local source location
│   │   ├── Batsu Hare
│   │   │   ├── Chapter 100 ...
│   │   ├── Grapara!
│   │   │   ├── Chapter 69 ...
│   │   ├── Guilty Circle
│   │   │   ├── Chapter 1 ...
│   │   ├── Isekai Saikouhou no Guild Leader
│   │   │   ├── Chapter 1 ....
│   │   └── Spy X Family
│   │       ├── Chapter 105.5 ....
└── manga-image-translator
    ├── * ...
    ├── batch-script.py # additional batch script file that I wrote to automate the translation.
```

---
## The First Steps: Getting the Basics Running
The `manga-image-translator` repo seems pretty solid at first try. It provide me the default script that can translate multiple chapters at once.
1. Scan the **INPUT_FOLDER** (.i.e. the `downloads` folder I set up above) for new chapters.
2. Run the manga translator command.
3. Save the output in a matching **OUTPUT_FOLDER**. (.i.e the `translated` folder)

Example set up:

```bash
sudo apt install cython3

conda create -n manga-trans python=3.12 pip

python -m manga_translator local -v -i ../suwayomi/data/downloads/mangas/Rawkuma\ \(JA\)/Grapara\!\ Raw/Chapter\ 13/ --output ../suwayomi/data/translated/Grapara\!\ Raw\ translated/Chapter\ 13/ --use-gpu --config-file examples/config-example.json
```

This worked, but there was one big problem: **it wasn’t fully automated** and has a lot of command flags that I need to remember. I had to manually re-run the script every time a new chapter arrived. Clearly, there had to be a better way.

---
## Automating the Pipeline: Watching for New Manga Chapters

I started exploring file-watching solutions and tested various Linux tools like **inotify** and **watchdog**. However, they didn’t track entire directories the way I needed. I wanted a script that:
- Monitors **INPUT_FOLDER** (and subfolders) for new content.
- Triggers translation **automatically** when a new chapter appears.
- Maintains the same folder structure in **OUTPUT_FOLDER**.

Enter Python **watchdog** library - a game-changer. With it, I wrote a script that:
1. Watches the manga download directory.
2. Detects when a new **chapter folder** appears.
3. Extracts the relative path and mirrors it in the output directory.

Here’s the script:
```python
import os
import time
import subprocess
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# ===== Configuration =====
INPUT_ROOT = "data/downloads/mangas/Rawkuma (JA)"
OUTPUT_ROOT = "data/translated"
CONFIG_FILE = "examples/config-example.json"
# ==========================


class TranslationHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            print(f"Detected new folder: {event.src_path}")
            self.process_new_folder(event.src_path)

    def process_new_folder(self, input_path):
        # Get relative path from input root
        relative_path = os.path.relpath(input_path, INPUT_ROOT)
        dest_path = os.path.join(OUTPUT_ROOT, relative_path)

        # Create output directory if it doesn't exist
        os.makedirs(dest_path, exist_ok=True)

        command = [
            "python",
            "-m",
            "manga_translator",
            "local",
            "-v",
            "-i",
            input_path,
            "--dest",
            dest_path,
            "--config-file",
            CONFIG_FILE,
            "--use-gpu",
        ]

        try:
            print(f"Starting translation for: {relative_path}")
            subprocess.run(command, check=True)
            print(f"Successfully translated: {relative_path}\n")
        except subprocess.CalledProcessError as e:
            print(f"Error translating {relative_path}:")
            print(f"The command failed with return code {e.returncode}")
            print("Command executed:", " ".join(command))


def main():
    # Validate paths
    if not os.path.isdir(INPUT_ROOT):
        raise ValueError(f"Input folder does not exist: {INPUT_ROOT}")
    os.makedirs(OUTPUT_ROOT, exist_ok=True)

    # Set up folder observer
    event_handler = TranslationHandler()
    observer = Observer()
    observer.schedule(event_handler, INPUT_ROOT, recursive=True)
    observer.start()

    try:
        print(f"Watching directory tree: {INPUT_ROOT}")
        print(f"Mirroring structure to: {OUTPUT_ROOT}")
        print("Press Ctrl+C to stop monitoring...")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == "__main__":
    main()
```
---
## Running It as a Background Service or a Docker container

I wanted the script to **run 24/7** without manually starting it each time. There are two ways to achieve this:
1. Run the Python script as a **systemd service** (requires tinkering with conda).
2. Run it as a Docker container (recommended)."*

### Option 1: systemd Service (for local installs, not recommended)
1. Created a new service file:
```bash
sudo nano /etc/systemd/system/manga-trans.service
```
2. Added this configuration:
```systemd
[Unit]
Description=Manga translation for Suwayomi
After=network.target

[Service]
User=1000
Group=1000
WorkingDirectory=/DATA/AppData/manga-image-translator
ExecStart=/bin/bash -c "source ~/miniforge3/etc/profile.d/conda.sh && conda activate manga-trans && python batch-script.py"

[Install]
WantedBy=multi-user.target
```
3. Enabled and started the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable manga-trans.service
sudo systemctl start manga-trans.service
```

### Option 2: Docker Container (recommended)
Rather than relying on conda, I containerized the entire application and push it to my own registry. To run it, you must first create a .env file to specify where the data gonna stored.
```
MANGA_FOLDER=/mnt/storage/media/manga
APPDATA=/mnt/storage/appdata/suwayomi
TZ=America/New_York
```

You also need to change the default location where the new manga will be download to in the Suwayomi web interface.

![](https://i.ibb.co/Ww5S681/image.png)


Here's my `docker-compose.yml` setup for the full stack deployment.

```yaml
name: suwayomi
services:
  suwayomi:
    container_name: suwayomi
    environment:
      - EXTENSION_REPOS=["https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"]
      - FLARESOLVERR_ENABLED=true
      - FLARESOLVERR_URL=http://flaresolverr:8191
      - TZ=${TZ}
    hostname: suwayomi
    image: ghcr.io/suwayomi/suwayomi-server:preview
    ports:
      - 4567:4567
    restart: always
    volumes:
      - ${MANGA_FOLDER}:/home/suwayomi/data
      - ${APPDATA}/data:/home/suwayomi/.local/share/Tachidesk

  flaresolverr:
    container_name: flaresolverr
    environment:
      - TZ=${TZ}
    hostname: flaresolverr
    image: ghcr.io/flaresolverr/flaresolverr:latest
    ports:
      - 8191:8191
    restart: unless-stopped

  manga-image-translator:
    # build:
    #   context: ${APPDATA}/manga-image-translator
    image: ghcr.io/phuchoang2603/manga-image-translator:v0.1.0
    container_name: manga-image-translator
    command: batch-script.py
    volumes:
      - ${APPDATA}/manga-image-translator/:/app/
      - ${APPDATA}/facehuggingcache:/root/.cache/huggingface/
      - ${MANGA_FOLDER}:/app/data
    ipc: host
    # For GPU
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
```

Now, it runs in the background **automatically** whenever I download a new manga chapter. No more waiting, no more manual intervention—just seamless reading.

---

## Final Thoughts

This project **completely transformed** how I read untranslated manga. No more screenshots, slow translators, or endless searching. Everything is automated, seamless, and runs quietly in the background.

If you're someone who digs through obscure manga titles like me, I highly recommend trying this out.