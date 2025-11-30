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
    const info = await youtube.getInfo(videoId);
    const title = info.basic_info.title || "video";
    const cleanTitle = title.replace(/[^a-z0-9]/gi, "_").toLowerCase();

    // Determine download type and format based on user selection
    let fileExtension: string;
    let contentType: string;
    let stream;

    if (format === "mp3") {
      // Audio download - use getInfo and download method
      fileExtension = "mp3";
      contentType = "audio/mpeg";

      try {
        stream = await info.download({
          type: "audio",
          quality: quality || "best",
        });
      } catch (error: any) {
        console.log(
          "Audio download error, trying with default settings:",
          error.message
        );
        // Fallback: try without quality specification
        stream = await info.download({
          type: "audio",
        });
      }
    } else {
      // Video download
      fileExtension = "mp4";
      contentType = "video/mp4";

      try {
        stream = await info.download({
          type: "video+audio",
          quality: quality || "best",
          format: "mp4",
        });
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
        } else {
          throw error;
        }
      }
    }

    // Set headers for download
    c.header("Content-Type", contentType);
    c.header(
      "Content-Disposition",
      `attachment; filename="${cleanTitle}.${fileExtension}"`
    );

    // Return the stream
    return new Response(stream as ReadableStream);
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
