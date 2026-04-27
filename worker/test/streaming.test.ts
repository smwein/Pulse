import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { SELF, fetchMock } from "cloudflare:test";

describe("SSE streaming", () => {
  beforeEach(() => {
    fetchMock.activate();
    fetchMock.disableNetConnect();
  });

  afterEach(() => {
    fetchMock.assertNoPendingInterceptors();
    fetchMock.deactivate();
  });

  it("returns text/event-stream content type", async () => {
    fetchMock
      .get("https://api.anthropic.com")
      .intercept({ path: "/v1/messages", method: "POST" })
      .reply(200, "data: hi\n\n");

    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "test-device-token" },
      body: JSON.stringify({ model: "x", messages: [] }),
    });

    expect(response.headers.get("content-type")).toBe("text/event-stream");
    expect(response.headers.get("cache-control")).toBe("no-cache");
  });

  it("preserves the upstream body bytes exactly", async () => {
    const upstreamPayload = "event: checkpoint\ndata: {\"label\":\"reading\"}\n\nevent: done\ndata: {}\n\n";
    fetchMock
      .get("https://api.anthropic.com")
      .intercept({ path: "/v1/messages", method: "POST" })
      .reply(200, upstreamPayload);

    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "test-device-token" },
      body: JSON.stringify({ model: "x", messages: [] }),
    });

    const text = await response.text();
    expect(text).toBe(upstreamPayload);
  });
});
