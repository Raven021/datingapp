import assert from "node:assert/strict";
import test from "node:test";
import { likeRate } from "./score";

test("like rate keeps a prior until eight shows", () => {
  assert.equal(likeRate(0, 0), 0.2);
  assert.equal(likeRate(4, 7), 0.2);
  assert.ok(Math.abs(likeRate(4, 10) - 6 / 20) < 1e-9);
  assert.ok(likeRate(4, 100) < likeRate(0, 0));
});
