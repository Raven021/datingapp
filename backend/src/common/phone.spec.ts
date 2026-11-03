import assert from "node:assert/strict";
import test from "node:test";
import { normalizePhone } from "./phone";

test("normalizes Iranian mobiles", () => {
  assert.equal(normalizePhone("09121234567"), "+989121234567");
  assert.equal(normalizePhone("+98 912 123 4567"), "+989121234567");
  assert.equal(normalizePhone("۰۹۱۲۱۲۳۴۵۶۷"), "+989121234567");
  assert.equal(normalizePhone("9121234567"), "+989121234567");
  assert.equal(normalizePhone("12345"), null);
});
