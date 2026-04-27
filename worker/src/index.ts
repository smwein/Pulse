export interface Env {
  ANTHROPIC_API_KEY: string;
  DEVICE_TOKEN: string;
}

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

function errorResponse(message: string, status: number): Response {
  return new Response(message, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method !== "POST") {
      return errorResponse("method not allowed", 405);
    }
    if (request.headers.get("X-Device-Token") !== env.DEVICE_TOKEN) {
      return errorResponse("forbidden", 403);
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return errorResponse("invalid json body", 400);
    }

    if (typeof body !== "object" || body === null || Array.isArray(body)) {
      return errorResponse("invalid json body: must be an object", 400);
    }

    // Force stream: true so the proxy is always streaming-only. Clients
    // shouldn't have to set this; if they pass stream: false we override.
    const upstreamBody = JSON.stringify({ ...body, stream: true });

    const upstream = await fetch(ANTHROPIC_URL, {
      method: "POST",
      headers: {
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
      },
      body: upstreamBody,
    });

    if (upstream.status >= 500) {
      return errorResponse(`upstream error ${upstream.status}`, 502);
    }

    // Successful streaming response: force SSE headers
    if (upstream.status === 200) {
      return new Response(upstream.body, {
        status: 200,
        headers: {
          "content-type": "text/event-stream",
          "cache-control": "no-cache",
        },
      });
    }

    // Non-200 (e.g. 429 rate limit, 400 bad request): pass through with
    // upstream's content-type and retry-after, but apply no-store caching.
    const passthroughHeaders = new Headers();
    const upstreamCT = upstream.headers.get("content-type");
    if (upstreamCT) passthroughHeaders.set("content-type", upstreamCT);
    const retryAfter = upstream.headers.get("retry-after");
    if (retryAfter) passthroughHeaders.set("retry-after", retryAfter);
    passthroughHeaders.set("cache-control", "no-store");

    return new Response(upstream.body, {
      status: upstream.status,
      headers: passthroughHeaders,
    });
  },
} satisfies ExportedHandler<Env>;
