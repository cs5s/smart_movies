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
 *   POST /groq                       -> forwards to Groq chat completions
 *   GET  /tmdb/search/multi          -> forwards to TMDB search
 *   GET  /tmdb/:mediaType/:id        -> forwards to TMDB details
 *   GET  /tmdb/:mediaType/:id/videos -> forwards to TMDB videos
 *   GET  /vodu-lookup?title=...      -> looks up (and caches) a Vodu page
 *                                        for the given show title
 *
 * Setup:
 *   1. npm install -g wrangler
 *   2. wrangler login
 *   3. wrangler init nero-proxy   (or copy this file into an existing worker)
 *   4. wrangler secret put GROQ_API_KEY
 *   5. wrangler secret put TMDB_API_KEY
 *   6. wrangler kv:namespace create VODU_CACHE
 *      -> paste the returned id into wrangler.toml (see wrangler.toml in this repo)
 *   7. wrangler deploy
 *   8. Copy the resulting *.workers.dev URL into `defaultApiBase` in main.dart
 */

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*", // tighten to your GitHub Pages domain once live
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// Normalizes a title so "Breaking Bad", "breaking bad ", "BREAKING BAD" all
// hit the same cache entry instead of being looked up (and scraped) again.
function cacheKeyFor(title) {
  return `vodu:${title.trim().toLowerCase().replace(/\s+/g, " ")}`;
}

async function handleVoduLookup(url, env) {
  const title = (url.searchParams.get("title") || "").trim();
  if (!title) {
    return jsonResponse({ error: "Missing 'title' query parameter" }, 400);
  }

  const key = cacheKeyFor(title);
  const searchUrl =
    `https://movie.vodu.me/index.php?do=search&subaction=search&story=${encodeURIComponent(title)}`;

  // 1. Serve from cache if we've already resolved this title before.
  if (env.VODU_CACHE) {
    try {
      const cached = await env.VODU_CACHE.get(key);
      if (cached) {
        return jsonResponse({ url: cached, matched: true, cached: true });
      }
    } catch (e) {
      // KV not bound or unavailable - fall through and do a live lookup.
    }
  }

  // 2. Live lookup: fetch Vodu's own search results page and pull out the
  //    first post link. This is plain URL/ID extraction (no article text
  //    or other content is read or stored) - just enough to build a link.
  try {
    const res = await fetch(searchUrl, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; NeroApp/1.0)" },
    });

    if (!res.ok) {
      return jsonResponse({ url: searchUrl, matched: false, cached: false });
    }

    const html = await res.text();
    const match = html.match(/index\.php\?do=view&type=post&id=(\d+)/i);

    if (match) {
      const directUrl = `https://movie.vodu.me/index.php?do=view&type=post&id=${match[1]}`;
      if (env.VODU_CACHE) {
        try {
          await env.VODU_CACHE.put(key, directUrl);
        } catch (e) {
          // Caching failed - not fatal, we still return the resolved URL.
        }
      }
      return jsonResponse({ url: directUrl, matched: true, cached: false });
    }

    // No result found on Vodu - hand back the search page itself so the
    // user can search/browse manually instead of hitting a dead end.
    return jsonResponse({ url: searchUrl, matched: false, cached: false });
  } catch (err) {
    return jsonResponse({ url: searchUrl, matched: false, error: err.message });
  }
}

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

        for (const [key, value] of url.searchParams) {
          tmdbUrl.searchParams.set(key, value);
        }
        tmdbUrl.searchParams.set("api_key", env.TMDB_API_KEY);

        const upstream = await fetch(tmdbUrl.toString());
        const text = await upstream.text();
        return new Response(text, {
          status: upstream.status,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      // ---- Vodu lookup (with caching) ----
      if (url.pathname === "/vodu-lookup" && request.method === "GET") {
        return await handleVoduLookup(url, env);
      }

      return jsonResponse({ error: "Not found" }, 404);
    } catch (err) {
      return jsonResponse({ error: err.message }, 500);
    }
  },
};