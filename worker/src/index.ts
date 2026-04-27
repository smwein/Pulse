export interface Env {
  ANTHROPIC_API_KEY: string;
  DEVICE_TOKEN: string;
}

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method !== "POST") {
      return new Response("method not allowed", { status: 405 });
    }
    if (request.headers.get("X-Device-Token") !== env.DEVICE_TOKEN) {
      return new Response("forbidden", { status: 403 });
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return new Response("invalid json body", { status: 400 });
    }

    const upstreamBody = JSON.stringify({ ...(body as object), stream: true });

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
      return new Response(`upstream error ${upstream.status}`, { status: 502 });
    }

    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        "content-type": "text/event-stream",
        "cache-control": "no-cache",
      },
    });
  },
} satisfies ExportedHandler<Env>;
