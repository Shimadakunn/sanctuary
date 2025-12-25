import { Hono } from "hono";
import { cors } from "hono/cors";
import { randomUUID } from "crypto";

const app = new Hono();

app.use("/*", cors());

type Format = "video" | "audio";
type Quality = "high" | "mid" | "low";
type DownloadStatus =
  | "pending"
  | "downloading"
  | "processing"
  | "completed"
  | "error";

interface DownloadRequest {
  url: string;
  format: Format;
  quality: Quality;
  title?: string;
}

interface DownloadSession {
  id: string;
  status: DownloadStatus;
  progress: number;
  format: Format;
  filename: string;
  filePath: string;
  error?: string;
  createdAt: number;
}

// In-memory store for download sessions
const downloadSessions = new Map<string, DownloadSession>();

// Clean up old sessions every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [id, session] of downloadSessions) {
    // Remove sessions older than 10 minutes
    if (now - session.createdAt > 10 * 60 * 1000) {
      downloadSessions.delete(id);
      // Clean up file if exists
      Bun.$`rm -f ${session.filePath}`.quiet().catch(() => {});
    }
  }
}, 5 * 60 * 1000);

const getYtDlpArgs = (
  url: string,
  format: Format,
  quality: Quality,
  outputPath: string
): string[] => {
  const baseArgs = ["--cookies", "./cookie.txt", "-o", outputPath, "--newline"];

  if (format === "audio") {
    return [
      ...baseArgs,
      "-x",
      "--audio-format",
      "mp3",
      "--audio-quality",
      quality === "high" ? "0" : quality === "mid" ? "5" : "9",
      url,
    ];
  }

  // Video format - force H.264 (avc1) codec for iOS compatibility
  const qualityMap: Record<Quality, string> = {
    high: "bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=1080][vcodec^=avc]+bestaudio/best[height<=1080]",
    mid: "bestvideo[height<=720][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=720][vcodec^=avc]+bestaudio/best[height<=720]",
    low: "bestvideo[height<=480][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=480][vcodec^=avc]+bestaudio/best[height<=480]",
  };

  return [
    ...baseArgs,
    "-f",
    qualityMap[quality],
    "--merge-output-format",
    "mp4",
    "--postprocessor-args",
    "ffmpeg:-c:v libx264 -c:a aac",
    url,
  ];
};

// Parse progress from yt-dlp output
const parseProgress = (line: string): number | null => {
  // Match patterns like "[download]  45.2% of 100.00MiB" or "[download] 100% of 100.00MiB"
  const match = line.match(/\[download\]\s+(\d+\.?\d*)%/);
  if (match) {
    return parseFloat(match[1]);
  }
  return null;
};

// Track which download phase we're in (video=1, audio=2)
interface ProgressTracker {
  phase: number;
  lastProgress: number;
}

const calculateOverallProgress = (
  rawProgress: number,
  tracker: ProgressTracker,
  isAudioOnly: boolean
): number => {
  if (isAudioOnly) {
    // Audio only: 0-90% for download, 90-100% for processing
    return rawProgress * 0.9;
  }

  // Video+Audio: phase 1 (video) = 0-45%, phase 2 (audio) = 45-90%, processing = 90-100%
  if (rawProgress < tracker.lastProgress && tracker.phase === 1) {
    // Progress reset means we moved to audio download
    tracker.phase = 2;
  }
  tracker.lastProgress = rawProgress;

  if (tracker.phase === 1) {
    return rawProgress * 0.45; // Video: 0-45%
  } else {
    return 45 + rawProgress * 0.45; // Audio: 45-90%
  }
};

// Start a download and return session ID
app.post("/start", async (c) => {
  const sessionId = randomUUID();
  const startTime = Date.now();

  console.log(`\n${"=".repeat(60)}`);
  console.log(`📥 [${sessionId.slice(0, 8)}] New download request received`);
  console.log(`⏰ Time: ${new Date().toISOString()}`);

  const body = await c.req.json<DownloadRequest>();
  const { url, format, quality, title } = body;

  console.log(`🔗 URL: ${url}`);
  console.log(`📦 Format: ${format}`);
  console.log(`📊 Quality: ${quality}`);
  console.log(`📝 Title: ${title || "(auto-detect)"}`);

  if (!url || !format || !quality) {
    console.log(`❌ [${sessionId.slice(0, 8)}] Error: Missing required fields`);
    return c.json(
      { error: "Missing required fields: url, format, quality" },
      400
    );
  }

  if (!["video", "audio"].includes(format)) {
    console.log(
      `❌ [${sessionId.slice(0, 8)}] Error: Invalid format "${format}"`
    );
    return c.json({ error: "Format must be 'video' or 'audio'" }, 400);
  }

  if (!["high", "mid", "low"].includes(quality)) {
    console.log(
      `❌ [${sessionId.slice(0, 8)}] Error: Invalid quality "${quality}"`
    );
    return c.json({ error: "Quality must be 'high', 'mid', or 'low'" }, 400);
  }

  const extension = format === "audio" ? "mp3" : "mp4";
  const outputPath = `/tmp/${sessionId}.%(ext)s`;
  const expectedFile = `/tmp/${sessionId}.${extension}`;

  // Get video title if not provided
  let videoTitle = title;
  if (!videoTitle) {
    console.log(`🔍 [${sessionId.slice(0, 8)}] Fetching video title...`);
    try {
      const titleProc = Bun.spawn(["yt-dlp", "--get-title", url], {
        stdout: "pipe",
        stderr: "pipe",
      });
      await titleProc.exited;
      videoTitle = (await new Response(titleProc.stdout).text()).trim();
      console.log(`📝 [${sessionId.slice(0, 8)}] Video title: "${videoTitle}"`);
    } catch {
      videoTitle = "download";
      console.log(
        `⚠️ [${sessionId.slice(0, 8)}] Could not fetch title, using default`
      );
    }
  }

  const safeTitle = videoTitle.replace(/[/\\?%*:|"<>]/g, "-");
  const filename = `${safeTitle}.${extension}`;

  // Create session
  const session: DownloadSession = {
    id: sessionId,
    status: "pending",
    progress: 0,
    format,
    filename,
    filePath: expectedFile,
    createdAt: startTime,
  };
  downloadSessions.set(sessionId, session);

  // Start download in background
  const args = getYtDlpArgs(url, format, quality, outputPath);
  console.log(`🚀 [${sessionId.slice(0, 8)}] Starting yt-dlp download...`);
  console.log(`   Command: yt-dlp ${args.join(" ")}`);

  // Run download process asynchronously
  const isAudioOnly = format === "audio";
  (async () => {
    try {
      session.status = "downloading";

      const proc = Bun.spawn(["yt-dlp", ...args], {
        cwd: import.meta.dir,
        stdout: "pipe",
        stderr: "pipe",
      });

      // Read stdout for progress
      const reader = proc.stdout.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      const progressTracker: ProgressTracker = { phase: 1, lastProgress: 0 };

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";

        for (const line of lines) {
          const rawProgress = parseProgress(line);
          if (rawProgress !== null) {
            const overallProgress = calculateOverallProgress(
              rawProgress,
              progressTracker,
              isAudioOnly
            );
            session.progress = overallProgress;
            if (overallProgress < 90) {
              session.status = "downloading";
            }
            console.log(
              `📊 [${sessionId.slice(
                0,
                8
              )}] Progress: ${overallProgress.toFixed(
                1
              )}% (raw: ${rawProgress.toFixed(1)}%, phase: ${
                progressTracker.phase
              })`
            );
          }
          // Check for post-processing
          if (
            line.includes("[Merger]") ||
            line.includes("[ExtractAudio]") ||
            line.includes("[ffmpeg]")
          ) {
            session.status = "processing";
            session.progress = 95;
            console.log(`⚙️ [${sessionId.slice(0, 8)}] Processing/Merging...`);
          }
        }
      }

      const exitCode = await proc.exited;
      const downloadTime = ((Date.now() - startTime) / 1000).toFixed(2);

      if (exitCode !== 0) {
        const stderr = await new Response(proc.stderr).text();
        console.log(
          `❌ [${sessionId.slice(
            0,
            8
          )}] yt-dlp failed with exit code ${exitCode}`
        );
        console.log(`   Error: ${stderr.slice(0, 500)}`);
        session.status = "error";
        session.error = stderr.slice(0, 200);
        return;
      }

      console.log(
        `✅ [${sessionId.slice(0, 8)}] yt-dlp completed in ${downloadTime}s`
      );

      const file = Bun.file(expectedFile);
      const exists = await file.exists();

      if (!exists) {
        console.log(
          `❌ [${sessionId.slice(0, 8)}] Error: Output file not found`
        );
        session.status = "error";
        session.error = "File not found after download";
        return;
      }

      const fileSizeMB = (file.size / 1024 / 1024).toFixed(2);
      console.log(`📁 [${sessionId.slice(0, 8)}] File ready: ${fileSizeMB} MB`);

      session.status = "completed";
      session.progress = 100;
      console.log(`✨ [${sessionId.slice(0, 8)}] Download completed!`);
      console.log(`${"=".repeat(60)}\n`);
    } catch (err) {
      console.log(`❌ [${sessionId.slice(0, 8)}] Error: ${String(err)}`);
      session.status = "error";
      session.error = String(err);
    }
  })();

  // Return session ID immediately
  return c.json({ sessionId, filename });
});

// Get download progress
app.get("/progress/:id", (c) => {
  const sessionId = c.req.param("id");
  const session = downloadSessions.get(sessionId);

  if (!session) {
    return c.json({ error: "Session not found" }, 404);
  }

  return c.json({
    status: session.status,
    progress: session.progress,
    filename: session.filename,
    error: session.error,
  });
});

// Download completed file
app.get("/file/:id", async (c) => {
  const sessionId = c.req.param("id");
  const session = downloadSessions.get(sessionId);

  if (!session) {
    return c.json({ error: "Session not found" }, 404);
  }

  if (session.status !== "completed") {
    return c.json(
      { error: "Download not completed", status: session.status },
      400
    );
  }

  const file = Bun.file(session.filePath);
  const exists = await file.exists();

  if (!exists) {
    return c.json({ error: "File not found" }, 404);
  }

  const contentType = session.format === "audio" ? "audio/mpeg" : "video/mp4";

  console.log(
    `📤 [${sessionId.slice(0, 8)}] Streaming file: "${session.filename}"`
  );

  // Clean up file and session after 60 seconds
  setTimeout(async () => {
    try {
      await Bun.$`rm -f ${session.filePath}`.quiet();
      downloadSessions.delete(sessionId);
      console.log(`🧹 [${sessionId.slice(0, 8)}] Cleaned up`);
    } catch {
      // Ignore cleanup errors
    }
  }, 60000);

  return new Response(file.stream(), {
    headers: {
      "Content-Type": contentType,
      "Content-Disposition": `attachment; filename="${session.filename}"`,
      "Content-Length": file.size.toString(),
    },
  });
});

app.get("/health", (c) => c.json({ status: "ok" }));

export default {
  port: 3000,
  hostname: "0.0.0.0",
  fetch: app.fetch,
};

console.log("Server running on http://0.0.0.0:3000");
