import assert from "node:assert/strict";
import {
  shiftSdkPlatforms,
  separateIntegrationPlatforms,
  supportsDirectSocialSdk,
  cloudExecutionPaused,
  assertLivePublishingEnabled,
} from "./platform-catalog.js";

assert.equal(shiftSdkPlatforms.length, 7);
assert.equal(new Set(shiftSdkPlatforms).size, shiftSdkPlatforms.length);
assert.equal(supportsDirectSocialSdk("instagram"), true);
assert.equal(supportsDirectSocialSdk("youtube"), true);
assert.equal(supportsDirectSocialSdk("facebook"), false);
assert.equal(supportsDirectSocialSdk("pinterest"), false);
assert.deepEqual(separateIntegrationPlatforms, ["facebook", "pinterest"]);
assert.equal(cloudExecutionPaused, true);
assert.throws(assertLivePublishingEnabled, /disabled/);
console.log("SHIFT platform catalog and cloud pause checks passed.");
