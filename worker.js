/**
 * NERO API Proxy — Cloudflare Worker
 * ------------------------------------------------------------
 * This is the ONLY place your real Groq and TMDB API keys should
 * ever live. The Flutter web app talks to this Worker, and the
 * Worker attaches the real keys before forwarding the request to
 * Groq / TMDB. The browser never sees the real keys, so it's safe
 * to publish the Flutter app's source (and this file) on GitHub.
 *
 * Routes:
 *   POST /groq                     -> forwards to Groq chat completions
 *   GET  /tmdb/search/multi        -> forwards to TMDB search
 *   GET  /tmdb/:mediaType/:id      -> forwards to TMDB details
 *   GET  /tmdb/:mediaType/:id/videos -> forwards to TMDB videos
 *
 * Setup:
 *   1. npm install -g wrangler
 *   2. wrangler login
 *   3. wrangler init nero-proxy   (or copy this file into an existing worker)
 *   4. wrangler secret put GROQ_API_KEY
 *   5. wrangler secret put TMDB_API_KEY
 *   6. wrangler deploy
 *   7. Copy the resulting *.workers.dev URL into `_defaultApiBase` in main.dart
 */

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*", // tighten to your GitHub Pages domain once live
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    try {
      // ---- Groq chat completions ----
      if (url.pathname === "/groq" && request.method === "POST") {
        const body = await request.text();
        const upstream = await fetch("https://api.groq.com/openai/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${env.GROQ_API_KEY}`,
          },
          body,
        });
        const text = await upstream.text();
        return new Response(text, {
          status: upstream.status,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      // ---- TMDB (search, details, videos) ----
      if (url.pathname.startsWith("/tmdb/") && request.method === "GET") {
        const tmdbPath = url.pathname.replace("/tmdb", "");
        const tmdbUrl = new URL(`https://api.themoviedb.org/3${tmdbPath}`);

        // Copy through all incoming query params (query, language, etc.)
        for (const [key, value] of url.searchParams) {
          tmdbUrl.searchParams.set(key, value);
        }
        // Always set the real key server-side, overriding anything a client sent.
        tmdbUrl.searchParams.set("api_key", env.TMDB_API_KEY);

        const upstream = await fetch(tmdbUrl.toString());
        const text = await upstream.text();
        return new Response(text, {
          status: upstream.status,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
  },
};