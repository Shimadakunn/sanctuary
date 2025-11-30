from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import yt_dlp
import os
import tempfile
import shutil

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
    temp_cookie_file = None
    try:
        # Locate the bundled cookie file
        current_dir = os.path.dirname(os.path.abspath(__file__))
        bundled_cookie_file = os.path.join(current_dir, 'www.youtube.com_cookies.txt')
        
        # Copy to temp file because Vercel file system is read-only and yt-dlp tries to write to the cookie file
        if os.path.exists(bundled_cookie_file):
            try:
                # Create a temp file
                fd, temp_cookie_file = tempfile.mkstemp(suffix=".txt", text=True)
                os.close(fd)
                # Copy content
                shutil.copy(bundled_cookie_file, temp_cookie_file)
                print(f"✅ Copied cookies to temp file: {temp_cookie_file}")
            except Exception as e:
                print(f"⚠️ Failed to copy cookie file: {e}")
                temp_cookie_file = None
        else:
            print(f"⚠️ CRITICAL: Cookie file not found at: {bundled_cookie_file}")

        # Configure yt-dlp options
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            # Prioritize known progressive MP4 formats (22=720p, 18=360p)
            # Then try any mp4 with audio that isn't m3u8
            # Fallback to best only as a last resort
            'format': '22/18/best[ext=mp4][acodec!=none][protocol!*=m3u8]/best',
            'verbose': True, # Enable verbose logging to debug auth issues
        }
        
        if temp_cookie_file:
            ydl_opts['cookiefile'] = temp_cookie_file

        if request.format == 'mp3':
             ydl_opts['format'] = 'bestaudio/best'
        elif request.quality:
            # Note: High qualities like 1080p usually require merging (ffmpeg), which we can't do.
            # We'll try to find the best single file available.
            if request.quality == '1080p':
                ydl_opts['format'] = 'best[height=1080][ext=mp4][acodec!=none]/22/18/best'
            elif request.quality == '720p':
                ydl_opts['format'] = '22/best[height=720][ext=mp4][acodec!=none]/18/best'

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(request.url, download=False)
            
            if 'entries' in info:
                info = info['entries'][0]

            # Debug logging for selected format
            print(f"ℹ️ Selected format: {info.get('format_id')} ({info.get('ext')}) - Protocol: {info.get('protocol')}")

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
        print(f"❌ Error processing request: {str(e)}")
        return JSONResponse(status_code=400, content={"error": str(e)})
    finally:
        # Cleanup temp file
        if temp_cookie_file and os.path.exists(temp_cookie_file):
            try:
                os.remove(temp_cookie_file)
                print(f"🧹 Cleaned up temp cookie file")
            except:
                pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
