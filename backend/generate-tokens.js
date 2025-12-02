// Script to generate po_token and visitor_data for YouTube authentication
import { spawn } from "child_process";

/**
 * Generates po_token and visitor_data using youtube-po-token-generator
 * @param {string} visitorData - Optional existing visitor_data
 * @returns {Promise<{visitorData: string, poToken: string}>}
 */
export async function generateTokens(visitorData = null) {
  return new Promise((resolve, reject) => {
    const args = visitorData ? [visitorData] : [];
    const generator = spawn("npx", [
      "youtube-po-token-generator",
      ...args,
    ]);

    let output = "";
    let errorOutput = "";

    generator.stdout.on("data", (data) => {
      output += data.toString();
    });

    generator.stderr.on("data", (data) => {
      errorOutput += data.toString();
    });

    generator.on("close", (code) => {
      if (code !== 0) {
        reject(
          new Error(`Token generation failed: ${errorOutput || output}`)
        );
        return;
      }

      try {
        // The output should be JSON with visitorData and poToken
        const result = JSON.parse(output.trim());
        resolve(result);
      } catch (error) {
        reject(new Error(`Failed to parse token output: ${output}`));
      }
    });

    // Set a timeout of 2 minutes
    setTimeout(() => {
      generator.kill();
      reject(new Error("Token generation timed out"));
    }, 120000);
  });
}

// If run directly, generate and display tokens
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log("🔑 Generating YouTube authentication tokens...");
  console.log(
    "⏳ This may take 30-60 seconds as it needs to simulate a browser...\n"
  );

  generateTokens()
    .then((tokens) => {
      console.log("✅ Tokens generated successfully!\n");
      console.log("📋 Copy these values to use in your backend:\n");
      console.log("Visitor Data:", tokens.visitorData);
      console.log("PO Token:", tokens.poToken);
      console.log("\n💡 Note: Tokens are typically valid for 12+ hours.");
    })
    .catch((error) => {
      console.error("❌ Error generating tokens:", error.message);
      process.exit(1);
    });
}
