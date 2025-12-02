# How to Extract PO Token and Visitor Data from Your Browser

## Method 1: Using Browser DevTools (Easiest)

1. Open Chrome/Firefox and go to YouTube.com
2. Open Developer Tools (F12 or Cmd+Option+I on Mac)
3. Go to the "Network" tab
4. Filter by "player" or "next"
5. Play any video or refresh the page
6. Click on one of the requests that appears
7. Look at the "Payload" or "Request Payload" tab
8. Find these values:
   - `po_token` (or `poToken`)
   - `visitor_data` (or `visitorData`)
9. Copy both values

## Method 2: Using Console (Quick)

1. Open YouTube.com
2. Open Developer Console (F12 → Console tab)
3. Paste this code and press Enter:

```javascript
(() => {
  try {
    // Try to get from ytcfg
    const poToken = ytcfg?.data_?.PO_TOKEN || ytcfg?.data_?.INNERTUBE_CONTEXT?.client?.visitorData;
    const visitorData = ytcfg?.data_?.VISITOR_DATA || ytcfg?.data_?.INNERTUBE_CONTEXT?.client?.visitorData;

    console.log('=== YouTube Tokens ===');
    console.log('PO Token:', poToken || 'Not found');
    console.log('Visitor Data:', visitorData || 'Not found');

    // Alternative: Check in cookies
    const cookies = document.cookie;
    const visitorMatch = cookies.match(/VISITOR_INFO1_LIVE=([^;]+)/);
    if (visitorMatch && !visitorData) {
      console.log('Visitor Data (from cookie):', visitorMatch[1]);
    }
  } catch (error) {
    console.error('Error extracting tokens:', error);
  }
})();
```

4. Copy the displayed tokens

## Method 3: Using curl/browser request inspection

1. Go to YouTube and play a video
2. Open Network tab in DevTools
3. Find a request to `youtubei/v1/player`
4. Right-click → Copy → Copy as cURL
5. Look for `"poToken"` and `"visitorData"` in the request body

## Setting the Tokens

Once you have the tokens, set them as environment variables:

### Option A: Environment Variables
```bash
export YOUTUBE_PO_TOKEN="your_po_token_here"
export YOUTUBE_VISITOR_DATA="your_visitor_data_here"
```

### Option B: Direct in code
Edit `backend/index.ts` and replace the empty strings:
```typescript
const YOUTUBE_CONFIG = {
  // ... cookie ...
  po_token: "your_po_token_here",
  visitor_data: "your_visitor_data_here",
};
```

## Important Notes

- **Tokens expire**: PO tokens typically last 12-24 hours
- **Per-video**: Some po_tokens are tied to specific videos
- **Privacy**: These tokens can make your session traceable to YouTube

## Troubleshooting

If you still get LOGIN_REQUIRED errors:
1. Make sure your cookies are fresh (copy from logged-in browser session)
2. Try generating new tokens
3. Check that tokens are properly formatted (no extra spaces/quotes)
