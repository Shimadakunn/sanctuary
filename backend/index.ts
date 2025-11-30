import { Hono } from "hono";
import { cors } from "hono/cors";
import { Innertube, Platform, UniversalCache } from "youtubei.js";

const app = new Hono();

// Enable CORS
app.use("/*", cors());

// Initialize YouTube client
let yt: Innertube;

// Set up custom JavaScript evaluator for deciphering URLs
// This is required to decipher YouTube's obfuscated streaming URLs
Platform.shim.eval = (data: any, env: any) => {
  const properties: string[] = [];

  if (env.n) {
    properties.push(`n: exportedVars.nFunction("${env.n}")`);
  }

  if (env.sig) {
    properties.push(`sig: exportedVars.sigFunction("${env.sig}")`);
  }

  const code = `${data.output}\nreturn { ${properties.join(", ")} }`;

  return new Function(code)();
};

async function initYouTube() {
  if (!yt) {
    // Suppress parser warnings
    const originalConsoleWarn = console.warn;
    console.warn = (...args) => {
      // Filter out YouTubeJS parser warnings
      if (args[0]?.includes?.('[YOUTUBEJS][Parser]')) {
        return;
      }
      originalConsoleWarn(...args);
    };

    yt = await Innertube.create({
      cache: new UniversalCache(false),
      generate_session_locally: true,
    });
  }
  return yt;
}

// Health check endpoint
app.get("/", (c) => {
  return c.json({
    message: "Video Downloader API",
    endpoints: {
      download: "POST /api/download - Download a video by URL or ID",
    },
  });
});

// Video download endpoint
app.post("/api/download", async (c) => {
  try {
    const body = await c.req.json();
    const { url, format = "mp4", quality = "best" } = body;

    // Log incoming request
    console.log("📥 [BACKEND] Received download request:");
    console.log("   URL:", url);
    console.log("   Format:", format);
    console.log("   Quality:", quality);

    if (!url) {
      return c.json({ error: "URL is required" }, 400);
    }

    // Validate format
    const validFormats = ["mp4", "mp3"];
    if (!validFormats.includes(format)) {
      return c.json(
        {
          error: "Invalid format",
          message: `Format must be one of: ${validFormats.join(", ")}`,
        },
        400
      );
    }

    // Extract video ID from URL or use as-is if it's already an ID
    let videoId = url;
    const urlPatterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/,
      /^([a-zA-Z0-9_-]{11})$/,
    ];

    for (const pattern of urlPatterns) {
      const match = url.match(pattern);
      if (match) {
        videoId = match[1];
        break;
      }
    }

    // Initialize YouTube client
    const youtube = await initYouTube();

    // Get detailed video info
    console.log("🔍 [BACKEND] Fetching video info for ID:", videoId);
    const info = await youtube.getInfo(videoId);
    const title = info.basic_info.title || "video";
    const cleanTitle = title.replace(/[^a-z0-9]/gi, "_").toLowerCase();

    console.log("📹 [BACKEND] Video title:", title);
    console.log("🎵 [BACKEND] Available formats count:", info.streaming_data?.formats?.length || 0);
    console.log("🎵 [BACKEND] Available adaptive formats count:", info.streaming_data?.adaptive_formats?.length || 0);

    // Log audio-only formats for debugging
    const audioFormats = info.streaming_data?.adaptive_formats?.filter((f: any) => f.has_audio && !f.has_video);
    console.log("🎵 [BACKEND] Audio-only formats available:", audioFormats?.length || 0);
    if (audioFormats && audioFormats.length > 0) {
      audioFormats.forEach((f: any, i: number) => {
        console.log(`   [${i}] ${f.mime_type} - ${f.bitrate} bps - ${f.audio_quality}`);
      });
    }

    // Determine download type and format based on user selection
    let fileExtension: string;
    let contentType: string;
    let stream;

    if (format === "mp3") {
      // Audio download - use getInfo and download method
      fileExtension = "mp3";
      contentType = "audio/mpeg";

      // Note: YouTube doesn't serve MP3 files directly. It serves audio/mp4 (m4a) or audio/webm (opus).
      // The quality parameter causes issues with URL deciphering, so we skip it for audio downloads.
      console.log("🎵 [BACKEND] Attempting MP3 download with type: 'audio' (no quality param to avoid decipher errors)");

      stream = await info.download({
        type: "audio",
      });
      console.log("✅ [BACKEND] MP3 download stream created successfully");
    } else {
      // Video download
      fileExtension = "mp4";
      contentType = "video/mp4";

      console.log("🎬 [BACKEND] Attempting MP4 download with type: 'video+audio', quality:", quality);

      try {
        stream = await info.download({
          type: "video+audio",
          quality: quality || "best",
          format: "mp4",
        });
        console.log("✅ [BACKEND] MP4 download stream created successfully");
      } catch (error: any) {
        if (error.message?.includes("No matching formats")) {
          console.log(
            `Quality "${quality}" not available, falling back to "best"`
          );
          stream = await info.download({
            type: "video+audio",
            quality: "best",
            format: "mp4",
          });
          console.log("✅ [BACKEND] MP4 download stream created (with fallback quality)");
        } else {
          throw error;
        }
      }
    }

    // Set headers for download
    console.log("📤 [BACKEND] Setting response headers:");
    console.log("   Content-Type:", contentType);
    console.log("   Filename:", `${cleanTitle}.${fileExtension}`);

    // Return the stream with proper headers
    console.log("✅ [BACKEND] Returning stream to client");
    return new Response(stream as ReadableStream, {
      headers: {
        "Content-Type": contentType,
        "Content-Disposition": `attachment; filename="${cleanTitle}.${fileExtension}"`,
      },
    });
  } catch (error) {
    console.error("Download error:", error);
    return c.json(
      {
        error: "Failed to download video",
        message: error instanceof Error ? error.message : "Unknown error",
      },
      500
    );
  }
});

// Get video info endpoint (optional)
app.post("/api/info", async (c) => {
  try {
    const body = await c.req.json();
    const { url } = body;

    if (!url) {
      return c.json({ error: "URL is required" }, 400);
    }

    // Extract video ID
    let videoId = url;
    const urlPatterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/,
      /^([a-zA-Z0-9_-]{11})$/,
    ];

    for (const pattern of urlPatterns) {
      const match = url.match(pattern);
      if (match) {
        videoId = match[1];
        break;
      }
    }

    const youtube = await initYouTube();
    const info = await youtube.getBasicInfo(videoId);

    return c.json({
      id: videoId,
      title: info.basic_info.title,
      author: info.basic_info.author,
      duration: info.basic_info.duration,
      viewCount: info.basic_info.view_count,
      thumbnail: info.basic_info.thumbnail?.[0]?.url,
    });
  } catch (error) {
    console.error("Info error:", error);
    return c.json(
      {
        error: "Failed to get video info",
        message: error instanceof Error ? error.message : "Unknown error",
      },
      500
    );
  }
});

const port = process.env.PORT || 3000;

console.log(`🔥 Server running on http://localhost:${port}`);

export default {
  port,
  fetch: app.fetch,
};
