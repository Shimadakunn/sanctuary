from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import yt_dlp
import tempfile
import os

app = FastAPI()

class DownloadRequest(BaseModel):
    url: str
    format: str = "mp4"
    quality: str = "best"

def create_cookie_file():
    """
    Creates a temporary Netscape-formatted cookie file with hardcoded cookies
    to bypass YouTube's bot detection.
    """
    content = """# Netscape HTTP Cookie File
.youtube.com\tTRUE\t/\tTRUE\t2147483647\t___Secure-YEC\tCgtPdEJ6bTJOLV9qcyiPnLPJBjInCgJGUhIhEh0SGwsMDg8QERITFBUWFxgZGhscHR4fICEiIyQlJiAZ
.youtube.com\tTRUE\t/\tTRUE\t2147483647\t___Secure-YENID\t11.YTE=HaHSKcFtBh67z980foL1bp4kfUtV9K9TocDOwTMlqDAlBKz_yfNVBWk9m6sKl-Y58rHqc3OT_cX28AvKj5CYt7DENwgo9-RUqiameEQDyEtZY7rEmciBMlOwY_Xhs7SgER5ervsN_RBxSTuNQ8KEkhkXw2kNsLh9csoy8g6BQo476Rgh7mNG1yeSfLUyXbUCIH8h1VuaeStnwa5gD8Fj6iylxfsAApKh_83SsP0-Kl-zAT0cZK_3vlChXuJ-3MP9UmXbpdSUSaRc3pBjVLZd4gWUIfdgbdiRIEotDxUaLCmfknlVA6pSmtQYwqIUOPgJCVdK71tjN7_UvoFHHf-LBQ
.youtube.com\tTRUE\t/\tTRUE\t2147483647\tPREF\tf4=4000000&f6=40000000&tz=Europe.Paris
"""
    # Create a temporary file. Vercel functions allow writing to /tmp.
    fd, path = tempfile.mkstemp(suffix=".txt", text=True)
    with os.fdopen(fd, 'w') as f:
        f.write(content)
    return path

@app.get("/")
def home():
    return {"message": "YouTube Downloader API is running"}

@app.post("/download")
def get_download_link(request: DownloadRequest):
    """
    Extracts the direct download URL for the requested YouTube video.
    """
    cookie_file = None
    try:
        # Create cookie file
        cookie_file = create_cookie_file()

        # Configure yt-dlp options
        # We prioritize 'best' which usually means best single file containing both video and audio
        # because we cannot merge streams (no FFmpeg on standard Vercel runtime).
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'format': 'best',
            'cookiefile': cookie_file,
        }

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
    finally:
        # Clean up the temporary cookie file
        if cookie_file and os.path.exists(cookie_file):
            try:
                os.remove(cookie_file)
            except:
                pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
