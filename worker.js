const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function cacheKeyFor(title) {
  return `vodu:${title.trim().toLowerCase().replace(/\s+/g, " ")}`;
}

async function handleVoduLookup(url, env) {
  const title = (url.searchParams.get("title") || "").trim();
  if (!title) return jsonResponse({ error: "Missing 'title' query parameter" }, 400);

  const key = cacheKeyFor(title);
  const searchUrl = `https://movie.vodu.me/index.php?do=search&subaction=search&story=${encodeURIComponent(title)}`;

  if (env.VODU_CACHE) {
    try {
      const cached = await env.VODU_CACHE.get(key);
      if (cached) return jsonResponse({ url: cached, matched: true, cached: true });
    } catch (e) {}
  }

  try {
    const res = await fetch(searchUrl, { headers: { "User-Agent": "Mozilla/5.0" } });
    if (!res.ok) return jsonResponse({ url: searchUrl, matched: false, cached: false });
    const html = await res.text();
    const match = html.match(/index\.php\?do=view&type=post&id=(\d+)/i);
    if (match) {
      const directUrl = `https://movie.vodu.me/index.php?do=view&type=post&id=${match[1]}`;
      if (env.VODU_CACHE) try { await env.VODU_CACHE.put(key, directUrl); } catch (e) {}
      return jsonResponse({ url: directUrl, matched: true, cached: false });
    }
    return jsonResponse({ url: searchUrl, matched: false, cached: false });
  } catch (err) {
    return jsonResponse({ url: searchUrl, matched: false, error: err.message });
  }
}

async function handleResolve(url) {
  const id = url.searchParams.get("id");
  const type = url.searchParams.get("type");
  const season = url.searchParams.get("season");
  const ep = url.searchParams.get("ep");
  const targetUrl = type === 'movie' 
    ? `https://vidsrc.pro/embed/movie/${id}`
    : `https://vidsrc.pro/embed/tv/${id}/${season}/${ep}`;

  try {
    const res = await fetch(targetUrl, { headers: { "User-Agent": "Mozilla/5.0" } });
    const html = await res.text();
    const match = html.match(/src=["'](https:\/\/vidsrc\.[^"']+)["']/i);
    if (match) return jsonResponse({ source: match[1] });
    return jsonResponse({ error: "Source not found" }, 404);
  } catch (e) {
    return jsonResponse({ error: e.message }, 500);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });

    try {
      if (url.pathname === "/resolve" && request.method === "GET") return await handleResolve(url);
      if (url.pathname === "/groq" && request.method === "POST") {
        const body = await request.text();
        const upstream = await fetch("https://api.groq.com/openai/v1/chat/completions", {
          method: "POST",
          headers: { "Content-Type": "application/json", "Authorization": `Bearer ${env.GROQ_API_KEY}` },
          body,
        });
        return new Response(await upstream.text(), { status: upstream.status, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
      }
      if (url.pathname.startsWith("/tmdb/") && request.method === "GET") {
        const tmdbPath = url.pathname.replace("/tmdb", "");
        const tmdbUrl = new URL(`https://api.themoviedb.org/3${tmdbPath}`);
        for (const [key, value] of url.searchParams) tmdbUrl.searchParams.set(key, value);
        tmdbUrl.searchParams.set("api_key", env.TMDB_API_KEY);
        const upstream = await fetch(tmdbUrl.toString());
        return new Response(await upstream.text(), { status: upstream.status, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
      }
      if (url.pathname === "/vodu-lookup" && request.method === "GET") return await handleVoduLookup(url, env);
      return jsonResponse({ error: "Not found" }, 404);
    } catch (err) {
      return jsonResponse({ error: err.message }, 500);
    }
  },
};