import { Hono } from 'hono';
import { exec } from 'youtube-dl-exec';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { existsSync } from 'node:fs';

const app = new Hono();

app.get('/', (c) => c.text('Youtube Downloader API is running! POST to /download'));

app.post('/download', async (c) => {
  try {
    const body = await c.req.json();
    const { url, format, title, quality } = body;

    if (!url) {
      return c.json({ error: 'URL is required' }, 400);
    }

    const targetFormat = format === 'mp3' ? 'mp3' : 'mp4';
    // Sanitize title: remove special chars, keep alphanumeric, dashes, underscores
    const safeTitle = (title || 'download').replace(/[^a-zA-Z0-9-_]/g, '_');
    const tempDir = tmpdir();
    // Template for youtube-dl
    const outputTemplate = join(tempDir, `${safeTitle}.%(ext)s`);
    
    // Flags for youtube-dl-exec
    const flags: any = {
      output: outputTemplate,
      noCheckCertificates: true,
      noWarnings: true,
      preferFreeFormats: true,
    };

    if (targetFormat === 'mp3') {
      flags.extractAudio = true;
      flags.audioFormat = 'mp3';
      // Note: ffmpeg is required on the system for audio extraction/conversion
    } else {
      // Video quality logic
      if (quality === 'high' || quality === 'best') {
        flags.format = 'bestvideo+bestaudio/best';
      } else if (quality === 'low' || quality === 'worst') {
        flags.format = 'worstvideo+worstaudio/worst';
      } else {
        // Default to best usually, or strictly following 'quality' if it's a specific resolution
        // Attempt to match resolution if provided like '1080p'
        if (quality && quality.endsWith('p')) {
             flags.format = `bestvideo[height<=${quality.replace('p','')}]+
bestaudio/best[height<=${quality.replace('p','')}]`;
        } else {
             flags.format = 'best';
        }
      }
      flags.mergeOutputFormat = 'mp4';
    }

    console.log(`Starting download for ${url} ...`);
    
    // Execute the download
    await exec(url, flags);

    // Construct the expected final file path
    const filePath = join(tempDir, `${safeTitle}.${targetFormat}`);

    if (!existsSync(filePath)) {
      console.error(`Expected file not found at ${filePath}`);
      return c.json({ error: 'Download completed but file not found.' }, 500);
    }

    const file = Bun.file(filePath);
    
    // Return the file as a download
    return new Response(file, {
      headers: {
        'Content-Type': targetFormat === 'mp3' ? 'audio/mpeg' : 'video/mp4',
        'Content-Disposition': `attachment; filename="${safeTitle}.${targetFormat}"`,
      },
    });
    
    // Note: The temporary file remains in the system temp directory.
    // A production-grade solution would schedule its deletion.

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

export default {
  port,
  fetch: app.fetch,
};
