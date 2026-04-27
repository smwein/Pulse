import { describe, it, expect } from "vitest";
import { SELF } from "cloudflare:test";

describe("device token auth", () => {
  it("rejects requests without X-Device-Token header with 403", async () => {
    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      body: JSON.stringify({ model: "test", messages: [] }),
    });
    expect(response.status).toBe(403);
  });

  it("rejects requests with an invalid X-Device-Token with 403", async () => {
    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      headers: { "X-Device-Token": "wrong-token" },
      body: JSON.stringify({ model: "test", messages: [] }),
    });
    expect(response.status).toBe(403);
  });

  it("403 response has cache-control: no-store", async () => {
    const response = await SELF.fetch("https://example.com/", {
      method: "POST",
      body: JSON.stringify({ model: "x", messages: [] }),
    });
    expect(response.status).toBe(403);
    expect(response.headers.get("cache-control")).toBe("no-store");
  });
});
