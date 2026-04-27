export interface Env {
  ANTHROPIC_API_KEY: string;
  DEVICE_TOKEN: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method !== "POST") {
      return new Response("method not allowed", { status: 405 });
    }
    if (request.headers.get("X-Device-Token") !== env.DEVICE_TOKEN) {
      return new Response("forbidden", { status: 403 });
    }
    return new Response("authenticated stub", { status: 200 });
  },
} satisfies ExportedHandler<Env>;
