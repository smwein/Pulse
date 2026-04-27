import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { SELF, fetchMock } from "cloudflare:test";

describe("forwarding to Anthropic", () => {
  beforeEach(() => {
    fetchMock.activate();
    fetchMock.disableNetConnect();
  });

  afterEach(() => {
    fetchMock.assertNoPendingInterceptors();
    fetchMock.deactivate();
  });

  it("forwards POST body to api.anthropic.com with the configured API key", async () => {
    let capturedRequest: { url: string; init: RequestInit } | undefined;

    fetchMock
      .get("https://api.anthropic.com")
      .intercept({ path: "/v1/messages", method: "POST" })
      .reply(200, (opts) => {
        capturedRequest = { url: "https://api.anthropic.com/v1/messages", init: opts as RequestInit };
        return "ok";
      }, { headers: { "content-type": "text/event-stream" } });

    const requestBody = { model: "claude-sonnet-4-6", messages: [{ role: "user", content: "hi" }] };

    await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: {
        "X-Device-Token": "test-device-token",
        "content-type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    expect(capturedRequest).toBeDefined();

    // Verify headers by making a fresh request to check what was forwarded
    // The interceptor captured opts which includes headers and body
    const opts = capturedRequest!.init as { headers?: Record<string, string>; body?: string };
    const headers = new Headers(opts.headers);
    expect(headers.get("x-api-key")).toBe("test-anthropic-key");
    expect(headers.get("anthropic-version")).toBe("2023-06-01");
    expect(headers.get("content-type")).toBe("application/json");

    const forwardedBody = JSON.parse(opts.body ?? "{}");
    expect(forwardedBody.model).toBe("claude-sonnet-4-6");
    expect(forwardedBody.messages).toEqual(requestBody.messages);
    expect(forwardedBody.stream).toBe(true);
  });

  it("returns the upstream response status to the caller", async () => {
    fetchMock
      .get("https://api.anthropic.com")
      .intercept({ path: "/v1/messages", method: "POST" })
      .reply(200, "ok");

    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "test-device-token" },
      body: JSON.stringify({ model: "x", messages: [] }),
    });

    expect(response.status).toBe(200);
  });

  it("returns 502 when upstream returns 5xx", async () => {
    fetchMock
      .get("https://api.anthropic.com")
      .intercept({ path: "/v1/messages", method: "POST" })
      .reply(500, "upstream error");

    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "test-device-token" },
      body: JSON.stringify({ model: "x", messages: [] }),
    });

    expect(response.status).toBe(502);
  });
});
