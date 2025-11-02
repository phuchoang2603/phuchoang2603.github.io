---
title: "Building an AI-Powered ArXiv Pipeline: Thought n8n was the future, but not yet"
description:
date: 2025-11-02
tags:
  - arxiv
  - mcp
  - n8n
  - python
  - hugo
draft: false
featureimage: https://i.ibb.co/chTK0Djn/image.png
---

This is my story of how I attempt to build an AI-powered pipeline for ArXiv papers. It was a journey that started with a cool idea about AI agents and ended with me wrestling Docker, n8n, and Python into submission.

{{< github repo="phuchoang2603/sis-arxiv-vad-papers" showThumbnail=true >}}

## Part 1: The AI Agent Dream (and Subsequent Nightmare)

My first idea was to build a smart AI agent using n8n that could talk to ArXiv. I wanted an LLM that could actually search for papers, download them, and even read them.

The [Docker Model Context Protocol (MCP)](https://github.com/docker/mcp-gateway) looked like the perfect tool for this. I found an `arxiv-mcp-server` on GitHub and my first task was just getting the thing to build.

### Building the ArXiv Server

{{< github repo="blazickjp/arxiv-mcp-server" showThumbnail=true >}}

I found the repo above, which had already configured an mcp server just as I wanted. However, when I attempted to get it running, I found the original `Dockerfile` was... a bit much. I figured I could simplify it using `uv`, since its official base images are clean and come with it pre-installed.

My new `Dockerfile` was way simpler:

```dockerfile
# Use a single Python base image with 'uv' pre-installed
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim
WORKDIR /app
COPY . .
# Install the project and all its deps
RUN uv pip install . --system
# Run the server
ENTRYPOINT ["python", "-m", "arxiv_mcp_server"]
```

### The "Stateless" Problem

With the server built, I set up a custom `catalog.yaml` above to define my tools and hooked it all into `docker-compose.yml`. A custom catalog is essentially your own personal, self-contained list of MCP servers. Instead of relying on a public registry, you define everything about the servers you want to use in a single `catalog.yaml` file.

The process is straightforward:

1. **Create `catalog.yaml`**: You define one or more servers in a YAML file following the specified format.
2. **Mount the Catalog**: In your `docker-compose.yml` file, you use a **volume mount** to make your local `catalog.yaml` file available inside the gateway container.
   - `volumes: - ./catalog.yaml:/mcp/catalog.yaml`
3. **Tell the Gateway to Use It**: You use `command` arguments to point the gateway to your mounted catalog file and specify which server(s) from that file you want to activate.
   - `command: - --catalog=/mcp/catalog.yaml - --servers=duckduckgo`

```yaml
registry:
  arxiv-mcp-server:
    title: "ArXiv MCP Server"
    description: "An MCP server that enables AI assistants to search, download, and read papers from the arXiv research repository."
    type: "server"
    image: "arxiv-mcp-server:latest"
    tools:
      - name: "search_papers"
      - name: "download_paper"
      - name: "list_papers"
      - name: "read_paper"
      - name: "deep-paper-analysis"

    env:
      - name: "ARXIV_STORAGE_PATH"
        value: "/data"

    volumes:
      - "/mnt/storage/media/docs:/data"
```

docker-compose file

```yaml
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    hostname: n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - N8N_HOST=${SUBDOMAIN}.${DOMAIN_NAME}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - N8N_RUNNERS_ENABLED=true
      - WEBHOOK_URL=https://${SUBDOMAIN}.${DOMAIN_NAME}/
      - OLLAMA_HOST=${OLLAMA_HOST:-ollama:11434}
      - TZ=${GENERIC_TIMEZONE}
    volumes:
      - ${APPDATA}/n8n/storage:/home/node/.n8n
      - ${SHARED_FOLDER}:/files
    restart: always

  mcp-gateway:
    image: docker/mcp-gateway
    hostname: mcp-gateway
    ports:
      - "8811:8811"
    command:
      - --servers=arxiv-mcp-server
      - --catalog=/mcp/catalog.yaml
      - --transport=sse
      - --port=8811
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./catalog.yaml:/mcp/catalog.yaml
```

I then wired it up in n8n with an AI Agent node, first trying a local `qwen3` model (way too slow) and then switching to `gpt-4o-mini` (much faster).

![](https://i.ibb.co/tpXRjGF4/image.png)

It worked\! The agent called the `search_papers` tool.

Then, I hit the first major wall. The agent would `download_paper`, and on the very next step, the `read_paper` tool would fail.

**The Problem:** The MCP gateway, by default, is _stateless_. It spins up a brand new container for _every single tool call_. The container that downloaded the paper was instantly destroyed, so the new container for `read_paper` had no idea the file existed. Bruh.

### The "Static" Mode Saga

The fix was `static=true` mode. This tells the gateway to connect to an _already-running_ server container. I dutifully refactored my `docker-compose.yml` to have `mcp-gateway` depend on a long-running `mcp-arxiv-server`.

```yaml
mcp-gateway:
  image: docker/mcp-gateway
  hostname: mcp-gateway
  ports:
    - "8811:8811"
  command:
    - --servers=arxiv-mcp-server,duckduckgo
    - --static=true
    - --transport=streaming
    - --port=8811
  depends_on:
    - mcp-arxiv-server

mcp-arxiv-server:
  image: mcp/arxiv-mcp-server
  entrypoint:
    ["/docker-mcp/misc/docker-mcp-bridge", "python", "-m", "arxiv_mcp_server"]
  init: true
  labels:
    - docker-mcp=true
    - docker-mcp-tool-type=mcp
    - docker-mcp-name=arxiv-mcp-server
    - docker-mcp-transport=stdio
  volumes:
    - type: image
      source: docker/mcp-gateway
      target: /docker-mcp
    - ${SHARED_FOLDER}:/app/papers
```

It failed.

I tried the _exact same setup_ with the official `duckduckgo` server, and it worked perfectly. My ArXiv server? Nothing. Just network errors.

![](https://i.ibb.co/7dg88QxW/image.png)

I was losing my mind, so I [filed a GitHub issue](https://github.com/docker/mcp-gateway/issues/154). A collaborator saved me. Turns out, the gateway _auto-prefixes_ the server name with `mcp-` to find the service.

My service was named `mcp-arxiv-server`. The gateway was looking for `mcp-mcp-arxiv-server`.

I renamed my service to `arxiv-mcp-server` (so the gateway would find it at `mcp-arxiv-mcp-server`) and just like that, it worked. The agent could finally search, download, and read papers in one session.

![](https://i.ibb.co/sdGJrLCq/image.png)

## Part 2: The New Task - Batch Processing 300 PDFs

Right after that win, I had a meeting with Lokman Belkit. We shifted gears. I now had a folder of 300 PDFs he'd sent me. The priority was no longer the live agent, but batch-processing this existing data.

![](https://i.ibb.co/chTK0Djn/image.png)

I needed a good PDF-to-Markdown converter. LlamaParse looked amazing, but you have to negotiate a license. No thanks. I settled on [Docling](https://github.com/docling-project/docling) because it was open-source and had a `docling-serve` image.

### Configuring `docling-serve`

This took _way_ longer than I expected. `docling-serve` is great, but it needs to download all its models before it can run. I ended up creating a two-stage setup in my `docker-compose.yml`:

1.  **`docling-serve-initial`:** A service that runs _once_ (`restart: "no"`) and just runs the download command, saving the models to a shared Docker volume.
2.  **`docling-serve`:** The main server. It `depends_on` the `initial` service, mounts that same volume, and reads the pre-downloaded models.

```yaml
services:
  # To download the required models before first run
  docling-serve-initial:
    image: ghcr.io/docling-project/docling-serve-cu126:main
    command:
      - docling-tools
      - models
      - download
      - --all
    volumes:
      - ${APPDATA}/n8n/docling_artifacts:/opt/app-root/src/.cache/docling/models
    restart: "no"

  # For document parsing
  docling-serve:
    image: ghcr.io/docling-project/docling-serve-cu126:main
    hostname: docling-serve
    ports:
      - "5001:5001"
    environment:
      DOCLING_SERVE_ENABLE_UI: "true"
      NVIDIA_VISIBLE_DEVICES: "all"
      DOCLING_SERVE_ARTIFACTS_PATH: "/models"
      DOCLING_SERVE_ENABLE_REMOTE_SERVICES: "true"
      DOCLING_SERVE_ALLOW_EXTERNAL_PLUGINS: "true"
    deploy: # This section is for compatibility with Swarm
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    volumes:
      - ${APPDATA}/n8n/docling_artifacts:/models
    runtime: nvidia
    restart: always
    depends_on:
      docling-serve-initial:
        condition: service_completed_successfully
```

First, I tried to get n8n to load all the papers from the `arxiv-existing` folder Lokman sent me. It contained 56 items, and it took a _really_ long time to load. Next, I started poking around the [docling API](https://github.com/docling-project/docling-serve/blob/fa1c5f04f33515de42bc2128cdc62714dc0c6f98/docs/usage.md). Before unleashing it on all 56 papers, I tested it out with just two to see what would actually happen.

I first tried _all_ of the features that `docling` offers:

- `pipeline` (str). The choice of which pipeline to use. Allowed values are `standard` and `vlm`. Defaults to `standard`.
- `do_table_structure` (bool): If enabled, the table structure will be extracted. Defaults to true.
- `do_code_enrichment` (bool): If enabled, perform OCR code enrichment. Defaults to false.
- `do_formula_enrichment` (bool): If enabled, perform formula OCR, return LaTeX code. Defaults to false.
- `do_picture_classification` (bool): If enabled, classify pictures in documents. Defaults to false.
- `do_picture_description` (bool): If enabled, describe pictures in documents. Defaults to false.

However, it took a **ridiculous** amount of time and memory to run, and it was prone to crashing. After digging around, I found out that other people were hitting this same [issue](https://github.com/docling-project/docling/issues/871). The formula and code awareness models, while small, will apparently eat your _entire_ GPU VRAM. So I had to turn off all the enrichments.

## Part 3: The n8n Orchestration Nightmare

This was my first time _really_ using n8n for a complex batch job, and honestly, it was frustrating.

**Problem 1: The ZIP File**
`docling-serve` returns a ZIP file with `paper.md` and an `artifacts/` folder. n8n's "Decompress" node doesn't output a nice array you can loop over. It's... not an array. It's a single item with multiple binary properties. After digging through forums, I found you have to use a custom Code node to manually split it:

```js
// This code is required to split a single item with multiple binary files
// into multiple items, each with one binary file.
let results = [];
for (item of items) {
  for (key of Object.keys(item.binary)) {
    results.push({
      json: { fileName: item.binary[key].fileName },
      binary: { data: item.binary[key] },
    });
  }
}
return results;
```

**Problem 2: Nested Loops are Buggy**
My next instinct was one giant workflow:

1.  Loop over all 50 PDFs.
2.  (Nested) Call Docling API.
3.  (Nested) Get the ZIP, run the code above.
4.  (Nested) Loop over the resulting files to save them.

This failed _miserably_. Data from the first paper's loop would "bleed" into the second paper's execution. It would just process the first paper over and over.

**The Solution: Master/Child Workflows**
The only stable solution was to refactor:

![](https://i.ibb.co/gZdbscGw/image.png)

1.  **Master Workflow:** Its _only_ job is to loop through the 50 PDFs and call a "Child" workflow _once per paper_.
2.  **Child Workflow:** Receives _one_ paper, calls Docling, saves the files, and finishes.

This isolated the execution and finally worked. I also created a `merge` node to filter out previously processed items, in case I wanted to run the workflow again in the future.

This process might _look_ easy, but it took me several hours. At first, I didn't know the `Edit Fields` node existed, so I was comparing the filenames directly, without realizing the file extensions were different (silly me). I had to modify the items in the `output` node, using an expression to cut the `.md` extension and replace it with `.pdf` just to get the filter to work.

In the end, it processed 39 papers in 11 minutes (with table enrichment on). A success... but it felt _way too_ complicated.

![](https://i.ibb.co/JWXNpWPd/image.png)

## Part 4: The Final Pivot - From n8n Hell to Python

The next step was extracting metadata from these new Markdown files.

I briefly tried `pdfVector` because of its JSON schema feature. Then I saw the price: **2 credits per page**. A 25-page paper would cost 75 credits. It was a complete non-starter. The results was actually good tho. At least I can utilize the JSON schema of it.

![](https://i.ibb.co/ccDVnLp2/image.png)

```json
{
  "type": "object",
  "properties": {
    "title": {
      "type": "string",
      "description": "Title of the research paper"
    },
    "type": {
      "type": "string",
      "description": "Type of the paper",
      "enum": [
        "method",
        "benchmark",
        "dataset",
        "application",
        "survey",
        "other"
      ]
    },
    "categories": {
      "type": "array",
      "description": "A list of the paper's methodology.",
      "items": {
        "type": "string",
        "enum": [
          "Weakly Supervised",
          "Semi Supervised",
          "Training Free",
          "Instruction Tuning",
          "Unsupervised",
          "Hybrid"
        ]
      }
    },
    "github_link": {
      "type": "string",
      "format": "url",
      "description": "Link to the GitHub repository (if available)",
      "nullable": true
    },
    "summary": {
      "type": "string",
      "description": "Description of the novelty of the paper"
    },
    "benchmarks": {
      "type": "array",
      "description": "A list of benchmarks used in the paper",
      "items": {
        "type": "string",
        "enum": [
          "cuhk-avenue",
          "shanghaitech",
          "xd-violence",
          "ubnormal",
          "ucf-crime",
          "ucsd-ped",
          "other"
        ]
      },
      "nullable": true
    },
    "authors": {
      "type": "array",
      "description": "A list of the paper's authors",
      "items": {
        "type": "string"
      }
    },
    "date": {
      "type": "string",
      "format": "date",
      "description": "Publication date of the paper (YYYY-MM-DD)"
    }
  },
  "required": ["title", "type", "categories", "date", "summary"],
  "additionalProperties": false
}
```

So I decided to roll my own json extractor on n8n. I added an "Information Extractor" node to my n8n workflow, using the JSON schema I'd built. Again, the local model disappointed me with inferior results.

- **Local `qwen3-4b`:** Failed to call the tool.
  ![](https://i.ibb.co/Myj1vsgR/image.png)
- **OpenRouter `gpt-4.1-nano`:** Worked perfectly.
  ![](https://i.ibb.co/xt4G92pq/image.png)

The final nail in the n8n-coffin came when I tried to set up my Hugo site. To make images work, Hugo needs a "Page Bundle" structure:

```
- content/
----papers/
-------<paper-name>/
-----------index.md
-----------artifacts/
---------------image.png
```

Trying to make n8n create this dynamic directory (`<paper-name>`) and rename the file to `index.md` was a joke. I was writing crazy expressions, using `Execute Command` nodes, `Edit Fields` nodes... it was just a mess.

I was so frustrated with how n8n handles basic file and path manipulation that I just gave up on it for orchestration.

### The Final Architecture: Python as the Orchestrator

I threw away the complex "Master" n8n workflow and replaced it with a single Python script.

This new hybrid architecture is the best of all worlds:

1.  **Python** (`main.py`) is the "Master." It's simple, I can debug it, and it handles file I/O perfectly.
2.  **Docker** runs my services (`docling-serve`, `n8n`, `mcp-server`).
3.  **n8n** is now just a simple "serverless function." It's a single webhook that receives a file path, extracts the JSON, and sends it back.

Here's the new flow:

1.  Python script loops through all PDFs.
2.  Calls `docling-serve` (running in Docker) to get the ZIP.
3.  Unzips the files locally into the correct Hugo Page Bundle structure (`<paper-name>/index.md`).
4.  Calls the **n8n webhook** with the absolute path to the new `index.md`.
5.  The **n8n workflow** reads the file, extracts the JSON using the LLM, and sends the JSON back as the webhook response.
6.  **Python** receives the JSON, formats it with `ruamel.yaml`, and writes it as front matter to the top of the `index.md`.
7.  The script moves the original PDF to a `done` folder.

{{< raw >}}

<div>
<iframe width="100%" height="480" src="https://www.youtube.com/embed/ytl1deWrZKI?si=RyuOQlYNeZXM318P" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
</div>
{{< /raw >}}

This journey was... a lot. But the final system is clean, robust, and a perfect example of using the right tool for the right job—even if it takes a few frustrating detours to find it.

