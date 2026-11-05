/** 
 * Offline-only integration smoke test. Does not publish to any real account.
 * Do not import this package into the Flutter application or browser.
 */
import { createSocial, connectedAccountRef } from "@opencoredev/social-sdk";
import { mockBackend } from "@opencoredev/social-sdk/testing";

async function main(): Promise<void> {
  const social = createSocial({
    backend: mockBackend({ scenario: "immediate-text-success" }),
  });

  const outcome = await social.posts.publish({
    targets: [{
      account: connectedAccountRef({
        backend: "default",
        platform: "x",
        accountId: "shift-mock-account",
      }),
    }],
    content: { text: "SHIFT Social SDK offline contract test" },
    idempotencyKey: "shift-offline-smoke-v1",
  });

  if (outcome.status !== "complete") {
    throw new Error(`Mock publish unexpectedly returned: ${outcome.status}`);
  }

  console.log("SHIFT Social SDK mock contract passed (no live publishing).");
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
