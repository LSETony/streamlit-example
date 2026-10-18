import { describe, expect, it } from "vitest";
import { parseSentryDsn, sentryEnvelope } from "./error-report";

describe("отчёты об ошибках", () => {
  it("разбирает DSN Sentry", () => {
    expect(parseSentryDsn("https://abc123@o42.ingest.sentry.io/777")).toEqual({
      url: "https://o42.ingest.sentry.io/api/777/envelope/",
      auth: "Sentry sentry_version=7, sentry_client=core-web/1.0, sentry_key=abc123",
    });
    expect(parseSentryDsn("not a dsn")).toBeNull();
  });

  it("не отправляет параметры запроса", () => {
    const env = sentryEnvelope({ message: "boom", path: "/clients?q=Иван", method: "GET" });
    const [, , event] = env.split("\n").map((l) => JSON.parse(l));
    expect(event.exception.values[0].value).toBe("boom");
    expect(env).not.toContain("Иван");
  });
});
