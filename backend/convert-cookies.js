// Convert Netscape cookie format to HTTP Cookie header format
import fs from "fs";

function convertCookies(netscapeCookies) {
  const lines = netscapeCookies.trim().split("\n");
  const cookies = [];

  for (const line of lines) {
    // Skip empty lines and comments
    if (!line.trim() || line.startsWith("#")) continue;

    // Split by tabs or multiple spaces
    const parts = line.split(/\t+|\s{2,}/);

    if (parts.length >= 7) {
      // Format: domain flag path secure expiration name value
      const name = parts[5].trim();
      const value = parts[6].trim();
      cookies.push(`${name}=${value}`);
    }
  }

  return cookies.join("; ");
}

// Read your cookies from a file or paste them here
const netscapeCookies = `
.youtube.com	TRUE	/	TRUE	1799189895	PREF	f4=4000000&f6=40000000&tz=Europe.Paris
.youtube.com	TRUE	/	TRUE	1798757477	__Secure-YENID	11.YTE=Oaer0WGymv1wuc9HvVHJaeEPnWWyBcA1_hs-t7Yi7e9PLGY22ICOxz6i7xMqX3DoFeOKyj3JDhJ5Df4PJnMuXq4hw2InN_z-hSkdwlLNsH2eAIOmvUbyEXtma4WofKa_Ed6Y8U7lh-4-ay6e31rNpCEaOuYHDsPa2hFPqiUZXVjck5vWb3y-8IqUgI4TnD3cDekv31vNwe728ja9pvxqGuMPRLmcZSFIYyuuFuvdPAX1Y1sOpxcP6Suvq5M1Hb3Yqil1YEqFTOX9U7g1SnItuJfTWfceETu7X8jztitsyFD-eTqR5_C-OsATMVgHrppKmPjIMIn3mkDPdYLHOkJKLQ
.youtube.com	TRUE	/	TRUE	1798757480	SOCS	CAISEwgDEgk4Mzg1MTQwNTkaAmVuIAEaBgiAtbPJBg
.youtube.com	TRUE	/	TRUE	1780181480	__Secure-BUCKET	CJkB
.youtube.com	TRUE	/	TRUE	1764631280	GPS	1
.youtube.com	TRUE	/	TRUE	1796165861	__Secure-1PSIDTS	sidts-CjUBwQ9iI_IgpgNT0186C8hSJoOQ7XEWdRaGSjalvnswYKkVFSPVM4VOQoeBqwpo7d9QrZ9lchAA
.youtube.com	TRUE	/	TRUE	1796165861	__Secure-3PSIDTS	sidts-CjUBwQ9iI_IgpgNT0186C8hSJoOQ7XEWdRaGSjalvnswYKkVFSPVM4VOQoeBqwpo7d9QrZ9lchAA
.youtube.com	TRUE	/	FALSE	1799189861	HSID	ACm6v3GpuW4N16ure
.youtube.com	TRUE	/	TRUE	1799189861	SSID	AwW985xrcyqfW97OM
.youtube.com	TRUE	/	FALSE	1799189861	APISID	LdmnkUULK_fGXlG-/AhZie6lVtc2PbNqxu
.youtube.com	TRUE	/	TRUE	1799189861	SAPISID	hHZSFoaDHtU3QGts/Ami7HEHdYPiViUYZS
.youtube.com	TRUE	/	TRUE	1799189861	__Secure-1PAPISID	hHZSFoaDHtU3QGts/Ami7HEHdYPiViUYZS
.youtube.com	TRUE	/	TRUE	1799189861	__Secure-3PAPISID	hHZSFoaDHtU3QGts/Ami7HEHdYPiViUYZS
.youtube.com	TRUE	/	FALSE	1799189861	SID	g.a0004AhytHS_3GBlu8yuCEaL2XAK6qlhLGwfTqozZ3dhy7zKuhi48fkOlPmEGeDnicaBNTxkLwACgYKAdASARYSFQHGX2MijgVOsMiLmbu0jSz-ER8KnBoVAUF8yKrg-skQLxPLWIU19CU4MOhn0076
.youtube.com	TRUE	/	TRUE	1799189861	__Secure-1PSID	g.a0004AhytHS_3GBlu8yuCEaL2XAK6qlhLGwfTqozZ3dhy7zKuhi4wpwK9pgI8ZYc6fRL2AjTZAACgYKATYSARYSFQHGX2MiIfzZxjFhMMBqHbhvzAxjURoVAUF8yKo6m3raCengK0FvMBVgFRKf0076
.youtube.com	TRUE	/	TRUE	1799189861	__Secure-3PSID	g.a0004AhytHS_3GBlu8yuCEaL2XAK6qlhLGwfTqozZ3dhy7zKuhi4Fa2ZOkLWYRqHsYZSbCeooAACgYKAaISARYSFQHGX2Mi-6yc-o5k8K6ADrDrbtypjxoVAUF8yKqyOoArBrIzshl8cwbNVY1r0076
.youtube.com	TRUE	/	TRUE	1799189862	LOGIN_INFO	AFmmF2swRAIgMvQ3h_opKrz32-l50RK8onBI7SXQXfGiN5tqJ8Aoay4CIAmHQzbl-13eb5BFwGy66ik2HuXNL2x21ExosaP0ROv3:QUQ3MjNmendGME4zbmxwN3FLTE9pWi1Ta2k3WjJraWxlTHdiVkUwOERuTDc0RlRVSHJNQkJteV9Ecy10cG5uaVo2ZGhJOTAtVm9OT0ZXTkVTaEVZZFBMajlpTEU2SGxLV19Od25DSWdXd1cta3BiOGpOSk5GSmluUm5mVTFNcHptVE0ySTNtWjVxQnZvSEQ1NkZGWFJ2bEJrTXdUYjQzR25n
.youtube.com	TRUE	/	TRUE	1780441063	NID	526=q-PZ5l5DozbS5pD1X4MpbtFLZyKbMH9sdq2D3h4IUYh60fwhLeywmsO8BmGmFU-AD5IhDx_xcvDvoLWjT7ThLb44_jcL6Y-GFAi5XrX7NHVGUoxuR3VvG2gZU_NNrYVJNwVeNBSkuLPl-XIayaJidWahy7Ajr79wDDB8VIKC79rtz5gP6PR_HqUwYjiBQEEzbkCKc5LeSaDZ77sAYcPMn5Y-DuOc_j9chXZgk_hCGnfXZxdmqTzvmtOt
.youtube.com	TRUE	/	TRUE	1764630466	CONSISTENCY	AKreu9vDWxBG63ijW9hMWiODyXQL3PQviJg2IOoiiNLjzIxOrqlQx3oGdidf0eTo3XW05g-wExUKnNV6wZSe6KaEQYntMYQXGz4sb-vFoQt9NqN4EgUSDpbq_TaEztFzJ8wJyFZKv8hQTNM7uPwpAO-A
.youtube.com	TRUE	/	FALSE	1796165897	SIDCC	AKEyXzUsNRoMNUT-8nFbkrzo4HqVd-G3M692QO_vuTPe39wuut_KqNLfL3Zi90ihdffK6SPFlA
.youtube.com	TRUE	/	TRUE	1796165897	__Secure-1PSIDCC	AKEyXzVfh3VCBgqTylxxNeck5Gt6x4OViPOqc_N6n26qkkpV0M96lcHYlhFLY3t05kykn5OP
.youtube.com	TRUE	/	TRUE	1796165897	__Secure-3PSIDCC	AKEyXzXMxNNTq94zTu97ehYddFvenkdLqlsDACFhvUJ2JiVM_MjFvafaYPKE37hmt4XTYeIlQg
.youtube.com	TRUE	/	TRUE	0	YSC	U8KVLJ67w44
.youtube.com	TRUE	/	TRUE	1780181893	VISITOR_INFO1_LIVE	c4AwRzs6-4c
.youtube.com	TRUE	/	TRUE	1780181893	VISITOR_PRIVACY_METADATA	CgJGUhIhEh0SGwsMDg8QERITFBUWFxgZGhscHR4fICEiIyQlJiBq
.youtube.com	TRUE	/	TRUE	1780181480	__Secure-ROLLOUT_TOKEN	CLKh996w5re9vAEQpu3fib2dkQMY7KG2ir2dkQM%3D
`;

const httpCookies = convertCookies(netscapeCookies);
console.log("HTTP Cookie Header Format:");
console.log(httpCookies);
console.log("\n\nUse this in your code:");
console.log(
  `const innertube = await Innertube.create({ cookie: '${httpCookies}' });`
);
