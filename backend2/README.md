# Bun Youtube Downloader API

A simple API built with [Bun](https://bun.sh) and [Hono](https://hono.dev) to download videos or audio from URLs using `youtube-dl-exec`.

## Prerequisites

- [Bun](https://bun.sh) installed.
- **Python** installed (required by `youtube-dl`).
- **FFmpeg** installed (required for audio extraction and format merging).
  - macOS: `brew install ffmpeg`
  - Linux: `sudo apt install ffmpeg`

## Installation

```bash
bun install
```

## Running the Server

```bash
bun start
# or for development with hot reload
bun dev
```

The server runs on `http://localhost:3000` by default.

## API Usage

### POST /download

Downloads a video or audio file.

**Request Body:**

```json
{
  "url": "https://www.youtube.com/watch?v=...",
  "format": "mp4",       // "mp4" or "mp3" (default: "mp4")
  "title": "My Video",   // Optional: filename preference
  "quality": "high"      // "high", "low", or resolution like "1080p" (default: "best")
}
```

**Example:**

```bash
curl -X POST http://localhost:3000/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "format": "mp4", "quality": "720p"}' \
  --output rickroll.mp4
```

## Notes

- Downloads are processed in the system's temporary directory.
- Large files may take time to process before the download starts.
- Ensure your IP is not blocked by the target site.