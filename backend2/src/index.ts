import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import youtubedl from 'youtube-dl-exec';

const app = new Hono();

app.get('/', (c) => c.text('Youtube Downloader API is running! POST to /download'));

app.post('/download', async (c) => {
  try {
    const body = await c.req.json();
    let { url, format, title, quality } = body;

    if (!url) {
      return c.json({ error: 'URL is required' }, 400);
    }

    // Basic URL validation
    try {
        new URL(url);
    } catch (e) {
        return c.json({ error: 'Invalid URL' }, 400);
    }

    // Get video info to determine filename if not provided
    let videoTitle = title;
    if (!videoTitle) {
        try {
            const info = await youtubedl(url, {
                dumpSingleJson: true,
                noCheckCertificates: true,
                noWarnings: true,
                preferFreeFormats: true,
            });
            // @ts-ignore
            videoTitle = info.title.replace(/[^a-zA-Z0-9-_]/g, '_');
        } catch (e) {
            videoTitle = 'video_' + Date.now();
            console.warn('Failed to fetch metadata, using fallback title:', e);
        }
    }

    let contentType = 'video/mp4';
    let contentExtension = 'mp4';
    let flags: any = {
        output: '-', // Output to stdout
        noCheckCertificates: true,
        noWarnings: true,
        preferFreeFormats: true,
    };

    if (format === 'mp3') {
        contentType = 'audio/mpeg';
        contentExtension = 'mp3';
        flags.extractAudio = true;
        flags.audioFormat = 'mp3';
        flags.format = 'bestaudio/best';
    } else {
        // Video
        contentType = 'video/mp4';
        contentExtension = 'mp4';
        
        // Quality selection
        if (quality === 'low' || quality === 'worst') {
             flags.format = 'worstvideo[ext=mp4]+bestaudio[ext=m4a]/worst[ext=mp4]/worst';
        } else if (quality && quality.endsWith('p')) {
            // Try to match resolution
            const height = quality.replace('p', '');
            flags.format = `bestvideo[height<=${height}][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best`;
        } else {
             // Default to best mp4
             flags.format = 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best';
        }
    }

    console.log(`Streaming ${format || 'video'} for ${videoTitle} from ${url}...`);

    // Execute yt-dlp and pipe stdout
    const subprocess = youtubedl.exec(url, flags, { 
        stdio: ['ignore', 'pipe', 'ignore'] 
    });

    const stream = subprocess.stdout;

    if (!stream) {
        throw new Error('Failed to create download stream');
    }

    return new Response(stream as any, {
        headers: {
            'Content-Type': contentType,
            'Content-Disposition': `attachment; filename="${videoTitle}.${contentExtension}"`,
        },
    });

  } catch (error: any) {
    console.error('Download error:', error);
    return c.json({ 
        error: 'Failed to process download', 
        details: error.message || String(error) 
    }, 500);
  }
});

const port = parseInt(process.env.PORT || '3000');
console.log(`Server starting on port ${port}...`);

serve({
  fetch: app.fetch,
  port
});

export default app;
