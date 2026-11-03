import assert from "node:assert/strict";
import test from "node:test";
import { isValidOpener, wordCount } from "./opener";

test("opener needs two words", () => {
  assert.equal(wordCount("سلام"), 1);
  assert.equal(isValidOpener("سلام"), false);
  assert.equal(isValidOpener("سلام خوبی"), true);
  assert.equal(isValidOpener("  سلام   چطوری  "), true);
  assert.equal(wordCount("می‌روم بیرون"), 2);
});
