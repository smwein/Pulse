export interface Env {
  ANTHROPIC_API_KEY: string;
  DEVICE_TOKEN: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return new Response("pulse-proxy stub", { status: 200 });
  },
} satisfies ExportedHandler<Env>;
