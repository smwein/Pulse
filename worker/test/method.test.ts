import { describe, it, expect } from "vitest";
import { SELF } from "cloudflare:test";

describe("HTTP method", () => {
  it("rejects GET with 405", async () => {
    const response = await SELF.fetch("https://example.com/", { method: "GET" });
    expect(response.status).toBe(405);
  });

  it("rejects PUT with 405", async () => {
    const response = await SELF.fetch("https://example.com/", { method: "PUT" });
    expect(response.status).toBe(405);
  });
});
