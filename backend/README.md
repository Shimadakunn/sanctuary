# Video Downloader API

A backend server built with Hono and youtubei.js for downloading YouTube videos.

## Features

- Download videos from YouTube by URL or video ID
- Get video information (title, author, duration, views)
- Built with Hono framework for high performance
- Uses youtubei.js for reliable video downloading
- CORS enabled for cross-origin requests

## Installation

```bash
bun install
```

## Running the Server

Development mode (with auto-reload):
```bash
bun run dev
```

Production mode:
```bash
bun start
```

The server will start on `http://localhost:3000` by default.

## API Endpoints

### GET /

Health check endpoint that returns API information.

**Response:**
```json
{
  "message": "Video Downloader API",
  "endpoints": {
    "download": "POST /api/download - Download a video by URL or ID"
  }
}
```

### POST /api/download

Download a YouTube video with customizable format and quality options.

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=VIDEO_ID",
  "format": "mp4",
  "quality": "best"
}
```

**Parameters:**
- `url` (required): YouTube video URL or video ID
- `format` (optional): Output format - `"mp4"` (video) or `"mp3"` (audio only). Default: `"mp4"`
- `quality` (optional): Video quality - `"best"`, `"high"`, `"medium"`, `"low"`, or specific resolutions like `"1080p"`, `"720p"`, `"480p"`, `"360p"`. Default: `"best"`

**Response:**
Returns a video or audio file as a download stream with appropriate headers.

**Examples:**

Download video in best quality (default):
```bash
curl -X POST http://localhost:3000/api/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}' \
  --output video.mp4
```

Download audio only (MP3):
```bash
curl -X POST http://localhost:3000/api/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "format": "mp3"}' \
  --output audio.mp3
```

Download video in 720p:
```bash
curl -X POST http://localhost:3000/api/download \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "quality": "720p"}' \
  --output video_720p.mp4
```

Download audio in medium quality:
```bash
curl -X POST http://localhost:3000/api/download \
  -H "Content-Type: application/json" \
  -d '{"url": "dQw4w9WgXcQ", "format": "mp3", "quality": "medium"}' \
  --output audio_medium.mp3
```

**Example using JavaScript fetch:**
```javascript
const response = await fetch('http://localhost:3000/api/download', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    format: 'mp4',
    quality: '720p'
  })
});

const blob = await response.blob();
const url = window.URL.createObjectURL(blob);
const a = document.createElement('a');
a.href = url;
a.download = 'video.mp4';
a.click();
```

### POST /api/info

Get information about a YouTube video without downloading it.

**Request Body:**
```json
{
  "url": "https://www.youtube.com/watch?v=VIDEO_ID"
}
```

**Response:**
```json
{
  "id": "VIDEO_ID",
  "title": "Video Title",
  "author": "Channel Name",
  "duration": 180,
  "viewCount": "1000000",
  "thumbnail": "https://..."
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/api/info \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}'
```

## Environment Variables

- `PORT`: Server port (default: 3000)

## Supported URL Formats

The API accepts various YouTube URL formats:
- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- `https://www.youtube.com/embed/VIDEO_ID`
- `VIDEO_ID` (just the 11-character ID)

## Error Handling

The API returns appropriate error messages:

**400 Bad Request:**
```json
{
  "error": "URL is required"
}
```

**500 Internal Server Error:**
```json
{
  "error": "Failed to download video",
  "message": "Error details..."
}
```

## Tech Stack

- [Bun](https://bun.sh/) - JavaScript runtime
- [Hono](https://hono.dev/) - Web framework
- [youtubei.js](https://github.com/LuanRT/YouTube.js) - YouTube API client

## Notes

- The download endpoint automatically fetches the best quality video with audio
- Video files are streamed directly to the client for memory efficiency
- Filenames are automatically sanitized and based on the video title
