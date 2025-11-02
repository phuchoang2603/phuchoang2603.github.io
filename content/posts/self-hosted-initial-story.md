---
title: "My First Server Was Office Trash: A Self-Hosting Story"
description:
date: 2023-08-27
tags:
  - self-hosted
  - proxmox
  - python
draft: false
featureimage: https://i.redd.it/47eryezt0xg91.png
---
It all started with a computer my mom saved from the trash heap at her office. It was a standard HP Prodesk 600 G4—nothing special, and since I already had a PC and a laptop, I had no idea what to do with it. Just installing Windows on it felt like a waste. I knew it could be something more than just another desktop collecting dust.

{{< youtubeLite id="zPmqbtKwtgw" label="Video demo" >}}

That simple idea kicked off a journey that completely changed what I thought I was passionate about and what I wanted to do with my life.

### My First, Clumsy Steps

My first goal was to create my own private server to back up all my photos. I stumbled upon something called **Xpenology**, which is a clever way to run the software from those fancy, expensive Synology servers on any old computer. I spent a whole night fighting with it. It was a huge pain. The whole thing relied on a specific USB stick that had to be plugged in all the time to trick the software into working. It felt messy and unreliable.

https://voz.vn/t/huong-dan-build-case-nas-xpenlogy-dsm-7-2-full-license-synology-surveillance-9-1-2-tan-dung-pc-cu.845346/

Frustrated, I kept searching and found **Proxmox**. This was the "aha!" moment. Proxmox is an operating system built specifically to run other computers _inside_ of it. Think of it like a digital nesting doll. It was stable, powerful, and let me create a virtual "computer" just for my photo backups. I could finally experiment and mess around without the fear of crashing everything. The beast was finally tamed.

{{< youtubeLite id="VOL-GLi8Qqw" label="Video demo" >}}

### Finding a Real Purpose (With a Little Help from a GPU)

The server was running, but I knew it could do more. Things got really interesting when I found an old, barely-working GT 1030 graphics card. It was the kind of thing most people would throw out, but I stuck it in the PC, and suddenly, a whole new world of projects opened up.

First, I built my own personal Netflix. I used a free program called **Jellyfin** to organize all my movies and TV shows into a slick interface. To get the media, I set up a few helper tools that people call the "**arr stack**" (Sonarr for TV, Radarr for movies) that automatically find and download stuff for me. That little graphics card did all the heavy lifting, converting video files on the fly so I could watch anything on my TV, laptop, or phone without any stuttering. If you want more detailed on how to properly set this up, here's the link https://trash-guides.info/. 

Next, I got into AI before ChatGPT was cool. I found a program called **Stable Diffusion** that can create images from just text descriptions. I had a pretty juvenile idea for a Telegram bot: you send it a picture, which then trigger a web-hook to a script I wrote to identify people clothes and send it to the Stable Diffusion server, which then ... well, let's just say "creatively redraw" the clothing. It was a ridiculous project born from a 16-year-old's hentai brain, but it taught me a ton about programming and how to connect different services together. Here's the repository if anyone interested https://github.com/phuchoang2603/telegram-sdwebui.

But the most meaningful thing I built was for my family. I connected our existing security cameras to a program called **Frigate**. Using the graphics card, Frigate is smart enough to tell the difference between a person walking up to our door and just a tree swaying in the wind. I then hooked Frigate into **Home Assistant**, which is like a central brain for smart home gadgets. Now, if someone is walking around our house late at night, my entire family gets an alert on their phones with a picture of what’s happening. It’s given us some real peace of mind, all powered by that old office PC.

![](https://i.ibb.co/Qs1ZKtv/image.png)


### The Obsession and the Path Forward

I was officially hooked. I found online communities like the `r/selfhosted` and `r/homelab` subreddits and discovered I wasn't alone. There are tons of people out there building amazing things in their own homes.

At first, all my projects only worked inside my house network. But what if I wanted to watch a movie while I was out, or share my photo server with a friend? I learned how to use something called a **Cloudflare Tunnel**. It sounds complicated, but it's a super secure way to let my projects be seen by the wider internet without opening up my home network to hackers.

Looking back, it’s wild. This whole journey started with a free computer that was about to be scrapped. In the process of tinkering, I accidentally taught myself about networking, Linux servers, and coding. I wasn't just building a server; I was discovering something I truly loved to do. It made me realize I didn't want to be a UX/UI designer anymore. I wanted to be the person who builds the stuff that works behind the scenes.

That old HP Prodesk didn't just find a new purpose; it gave me one, too.