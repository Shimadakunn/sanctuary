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
            'quiet': True, # We will manually print formats
            'no_warnings': True,
            # STRICTLY require a direct HTTP/HTTPS link.
            # We cannot handle m3u8 (HLS) or dash because the iOS app simply downloads the URL.
            # Downloading an m3u8 URL just saves the text playlist, not the video content.
            'format': '(best[ext=mp4]/best)[protocol^=http]',
            'verbose': True, 
            'http_headers': {
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
                'Accept-Language': 'en-US,en;q=0.9',
                'Sec-Fetch-Mode': 'navigate',
                'Sec-Fetch-Site': 'none',
                'Sec-Fetch-User': '?1',
                'Sec-Fetch-Dest': 'document',
                'Upgrade-Insecure-Requests': '1',
                'sec-ch-ua': '"Google Chrome";v="123", "Not:A-Brand";v="8", "Chromium";v="123"',
                'sec-ch-ua-mobile': '?0',
                'sec-ch-ua-platform': '"macOS"',
                'Referer': 'https://www.youtube.com/',
                'Origin': 'https://www.youtube.com'
            }
        }
        
        if temp_cookie_file:
            ydl_opts['cookiefile'] = temp_cookie_file

        if request.format == 'mp3':
             ydl_opts['format'] = 'bestaudio/best'
        elif request.quality:
            if request.quality == '1080p':
                ydl_opts['format'] = '(best[height=1080][ext=mp4]/best)[protocol^=http]'
            elif request.quality == '720p':
                ydl_opts['format'] = '(best[height=720][ext=mp4]/best)[protocol^=http]'

        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(request.url, download=False)
            
            # DEBUG: Print all available formats to help diagnose missing progressive streams
            if 'formats' in info:
                print(f"\n🔎 Available Formats for '{info.get('title', 'Unknown')}':")
                print(f"{'ID':<5} {'EXT':<5} {'RES':<10} {'PROTO':<10} {'NOTE'}")
                print("-" * 50)
                for f in info['formats']:
                    f_id = f.get('format_id', 'N/A')
                    f_ext = f.get('ext', 'N/A')
                    f_res = f.get('resolution', 'N/A')
                    f_proto = f.get('protocol', 'N/A')
                    f_note = f.get('format_note', '')
                    print(f"{f_id:<5} {f_ext:<5} {f_res:<10} {f_proto:<10} {f_note}")
                print("-" * 50 + "\n")

            if 'entries' in info:
                info = info['entries'][0]

            # Debug logging for selected format
            print(f"✅ Selected format: ID={info.get('format_id')} Ext={info.get('ext')} Proto={info.get('protocol')} Res={info.get('resolution')}")

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
