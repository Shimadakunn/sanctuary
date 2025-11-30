from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import yt_dlp
import os

app = FastAPI()

class DownloadRequest(BaseModel):
    url: str
    format: str = "mp4"
    quality: str = "best"

@app.get("/")
def home():
    return {"message": "YouTube Downloader API is running"}

@app.post("/download")
def get_download_link(request: DownloadRequest):
    """
    Extracts the direct download URL for the requested YouTube video.
    """
    try:
        # Locate the cookie file
        # Script is in /api, cookie file is in root / (backend_python/)
        current_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(current_dir)
        cookie_file = os.path.join(project_root, 'www.youtube.com_cookies.txt')

        # Check if file exists, fallback to checking current directory if path logic fails
        if not os.path.exists(cookie_file):
            if os.path.exists('www.youtube.com_cookies.txt'):
                cookie_file = 'www.youtube.com_cookies.txt'
            else:
                print(f"⚠️ Cookie file not found at: {cookie_file}")
                cookie_file = None

        # Configure yt-dlp options
        # We prioritize 'best' which usually means best single file containing both video and audio
        # because we cannot merge streams (no FFmpeg on standard Vercel runtime).
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'format': 'best',
        }
        
        if cookie_file:
            ydl_opts['cookiefile'] = cookie_file

        if request.format == 'mp3':
             # Requesting best audio. Usually returns m4a or webm. 
             # Real MP3 conversion requires FFmpeg.
             ydl_opts['format'] = 'bestaudio/best'
        elif request.quality:
            if request.quality == '1080p':
                # Try to get 1080p mp4 if available as single file (rare for YT), fallback to best
                ydl_opts['format'] = 'best[height=1080][ext=mp4]/best[height>=720][ext=mp4]/best'
            elif request.quality == '720p':
                ydl_opts['format'] = 'best[height=720][ext=mp4]/best'

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(request.url, download=False)
            
            if 'entries' in info:
                info = info['entries'][0]

            video_url = info.get('url')
            title = info.get('title')
            ext = info.get('ext')
            thumbnail = info.get('thumbnail')
            
            return {
                "title": title,
                "url": video_url,
                "thumbnail": thumbnail,
                "requested_format": request.format,
                "requested_quality": request.quality,
                "actual_format": ext,
                "note": "Direct link generated. If format/quality differs, it is due to server-side limitations (missing FFmpeg for merging/converting)."
            }

    except Exception as e:
        return JSONResponse(status_code=400, content={"error": str(e)})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
