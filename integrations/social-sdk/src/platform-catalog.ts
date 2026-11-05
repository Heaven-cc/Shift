/**
 * Server-side SDK platform metadata used by SHIFT.
 * Adapter support != OAuth connected, account eligibility, or live publishing.
 */
export const shiftSdkPlatforms = [
  "instagram", "tiktok", "linkedin", "x", "threads", "youtube", "bluesky",
] as const;

export type ShiftSdkPlatform = (typeof shiftSdkPlatforms)[number];

export const separateIntegrationPlatforms = ["facebook", "pinterest"] as const;

export const cloudExecutionPaused = true as const;

export function supportsDirectSocialSdk(platform: string): platform is ShiftSdkPlatform {
  return (shiftSdkPlatforms as readonly string[]).includes(platform);
}

/** No publishing may occur until server-side setup and explicit authorization. */
export function assertLivePublishingEnabled(): never {
  throw new Error(
    "SHIFT live publishing is disabled: secure OAuth and manual publish API not configured. Background automation paused.",
  );
}
