# YouTube Downloader API (Vercel Ready)

This is a simple FastAPI application that uses `yt-dlp` to extract direct download links from YouTube videos. It is configured for deployment on Vercel.

## Local Development

1.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

2.  **Run the server:**
    ```bash
    python api/index.py
    ```
    Or using uvicorn directly:
    ```bash
    uvicorn api.index:app --reload
    ```

3.  **Test the endpoint:**
    Send a POST request to `http://localhost:8000/download` with a JSON body:
    ```json
    {
      "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "format": "mp4",
      "quality": "720p"
    }
    ```

## Deployment to Vercel

1.  Install the Vercel CLI: `npm i -g vercel`
2.  Run `vercel` in this directory and follow the prompts.

## Notes
-   **FFmpeg Limitation:** Vercel's serverless environment does not include FFmpeg by default. Merging video+audio (required for 1080p+) or converting to true MP3 is not supported in this basic setup. The API will attempt to return the best available single-file stream (usually 720p MP4 or M4A/WebM for audio).
-   **URL Expiration:** The generated links are direct streams from Google's servers and may expire or be IP-locked.
