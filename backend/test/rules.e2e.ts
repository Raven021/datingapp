import "reflect-metadata";
import assert from "node:assert/strict";
import fs from "fs/promises";
import os from "os";
import path from "path";
import test from "node:test";
import { INestApplication } from "@nestjs/common";
import { PrismaClient } from "@prisma/client";
import sharp from "sharp";
import { createApp } from "../src/app";
import { loadEnv } from "../src/load-env";
import { PrismaService } from "../src/prisma/prisma.service";
import { ARMAN_ID, REZA_ID, seedDemo, TINA_ID } from "../prisma/seed";
import { TEHRAN_ID } from "../prisma/cities";

loadEnv(path.join(__dirname, "../.env"));
const uploadDir = path.join(os.tmpdir(), `ashna-e2e-${process.pid}`);
process.env.DATABASE_URL = "postgresql://dating:dating@127.0.0.1:5432/dating_test";
process.env.UPLOAD_DIR = uploadDir;
process.env.OTP_DEV_CODE = "123456";
process.env.PUBLIC_BASE_URL = "http://127.0.0.1:3000";

let app: INestApplication;
let base: string;
let prisma: PrismaClient;

test("product rules", async (t) => {
  await t.test("boots and enforces the loop", async () => {
    await fs.mkdir(uploadDir, { recursive: true });
    app = await createApp(true);
    await app.listen(0);
    const address = app.getHttpServer().address();
    assert.ok(address && typeof address === "object");
    base = `http://127.0.0.1:${address.port}`;
    prisma = app.get(PrismaService);
    await prisma.$executeRawUnsafe(`
      TRUNCATE TABLE
        messages, reports, blocks, impressions, swipes, matches,
        photos, devices, refresh_tokens, preferences, profiles, users, cities
      RESTART IDENTITY CASCADE
    `);
    await seedDemo(prisma, uploadDir);

    const tina = await login("09120000001");
    const deck = await api("GET", "/v1/deck", { token: tina.accessToken });
    assert.equal(deck.status, 200);
    const cards = deck.json.cards as Array<Record<string, unknown>>;
    const names = cards.map((card) => card.displayName);
    const arman = names.indexOf("آرمان");
    const reza = names.indexOf("رضا");
    assert.ok(arman >= 0 && reza >= 0, `deck was ${names.join("، ")}`);
    assert.ok(arman < reza, `آرمان should sort ahead of رضا, got ${names.join("، ")}`);
    assert.equal(cards[0].displayName, "آرمان");
    for (const card of cards) {
      assert.equal("likedMe" in card, false);
      assert.equal("liked_me" in card, false);
      assert.equal("rate" in card, false);
      assert.equal("latitude" in card, false);
      assert.equal("longitude" in card, false);
      assert.ok(Array.isArray(card.photos) && (card.photos as unknown[]).length >= 2);
    }
    assert.equal(names.includes("سارا"), false);

    const me = await api("GET", "/v1/me", { token: tina.accessToken });
    assert.equal(me.json.profile.displayName, "تینا");
    assert.equal("latitude" in (me.json.profile as object), false);

    const child = await signup("09121000999", {
      displayName: "کودک",
      birthDate: "2015-01-01",
      gender: "woman",
      showGenders: ["man"],
      cityId: TEHRAN_ID,
    });
    assert.equal(child.status, 400);
    assert.equal(child.json.code, "UNDERAGE");

    const neda = await readyUser("09121000021", "ندا", "woman", ["man"]);
    const pouya = await readyUser("09121000022", "پویا", "man", ["woman"]);
    const first = await api("POST", "/v1/swipes", {
      token: neda.token,
      body: { userId: pouya.id, direction: "like" },
    });
    assert.equal(first.json.match, null);
    const second = await api("POST", "/v1/swipes", {
      token: pouya.token,
      body: { userId: neda.id, direction: "like" },
    });
    assert.ok(second.json.match?.id);
    const matchId = second.json.match.id as string;
    assert.equal(second.json.match.status, "pending");

    const short = await api("POST", `/v1/matches/${matchId}/messages`, {
      token: neda.token,
      body: { body: "سلام" },
    });
    assert.equal(short.status, 400);
    assert.equal(short.json.code, "OPENER_TOO_SHORT");
    const stored = await api("GET", `/v1/matches/${matchId}/messages`, { token: neda.token });
    assert.equal(stored.json.messages.length, 0);

    const opener = await api("POST", `/v1/matches/${matchId}/messages`, {
      token: neda.token,
      body: { body: "سلام خوبی" },
    });
    assert.equal(opener.status, 201);
    const again = await api("POST", `/v1/matches/${matchId}/messages`, {
      token: neda.token,
      body: { body: "یه پیام دیگه" },
    });
    assert.equal(again.status, 400);
    assert.equal(again.json.code, "WAITING_FOR_REPLY");

    const reply = await api("POST", `/v1/matches/${matchId}/messages`, {
      token: pouya.token,
      body: { body: "باشه" },
    });
    assert.equal(reply.status, 201);
    const unlocked = await api("GET", `/v1/matches/${matchId}/messages`, { token: neda.token });
    assert.equal(unlocked.json.status, "active");
    const free = await api("POST", `/v1/matches/${matchId}/messages`, {
      token: neda.token,
      body: { body: "خب" },
    });
    assert.equal(free.status, 201);

    const left = await readyUser("09121000031", "چپ", "woman", ["man"], { latitude: 35.6892, longitude: 51.389 });
    const right = await readyUser("09121000032", "راست", "man", ["woman"], { latitude: 35.734, longitude: 51.389 });
    await api("PUT", "/v1/me", {
      token: right.token,
      body: profileBody("راست", "man", ["woman"], { maxDistanceKm: 1 }),
    });
    const far = await api("GET", "/v1/deck", { token: left.token });
    const farNames = (far.json.cards as Array<{ displayName: string }>).map((card) => card.displayName);
    assert.equal(farNames.includes("راست"), false);

    const near = await readyUser("09121000033", "نزدیک", "man", ["woman"], { latitude: 35.692, longitude: 51.389 });
    const closeDeck = await api("GET", "/v1/deck", { token: left.token });
    const closeCard = (closeDeck.json.cards as Array<{ displayName: string; distanceKm: number | null }>).find(
      (card) => card.displayName === "نزدیک",
    );
    assert.ok(closeCard);
    assert.equal(closeCard.distanceKm, 0);

    const blocked = await readyUser("09121000041", "مسدود", "man", ["woman"]);
    const hide = await api("POST", "/v1/blocks", { token: tina.accessToken, body: { phone: "09121000041" } });
    assert.equal(hide.status, 201);
    const tinaDeck = await api("GET", "/v1/deck", { token: tina.accessToken });
    assert.equal(
      (tinaDeck.json.cards as Array<{ id: string }>).some((card) => card.id === blocked.id),
      false,
    );
    const otherDeck = await api("GET", "/v1/deck", { token: blocked.token });
    assert.equal(
      (otherDeck.json.cards as Array<{ id: string }>).some((card) => card.id === TINA_ID),
      false,
    );

    const plain = await sharp({
      create: { width: 24, height: 24, channels: 3, background: { r: 20, g: 40, b: 200 } },
    })
      .jpeg()
      .toBuffer();
    const marked = withMarker(plain, "GPSLATSECRET");
    assert.ok(marked.includes(Buffer.from("GPSLATSECRET")));
    const uploaded = await upload(tina.accessToken, marked);
    assert.equal(uploaded.status, 201);
    const saved = await fs.readFile(path.join(uploadDir, TINA_ID, `${uploaded.json.id}.jpg`));
    assert.equal(saved.includes(Buffer.from("GPSLATSECRET")), false);
    assert.equal(saved[0], 0xff);
    assert.equal(saved[1], 0xd8);
    const media = await fetch(`${base}/v1/media/${uploaded.json.id}`, {
      headers: { Authorization: `Bearer ${tina.accessToken}` },
    });
    assert.equal(media.status, 200);

    const removed = await api("DELETE", "/v1/me", { token: blocked.token });
    assert.equal(removed.status, 200);
    const gone = await api("GET", "/v1/me", { token: blocked.token });
    assert.equal(gone.status, 401);

    assert.ok(ARMAN_ID && REZA_ID);
  });
});

test.after(async () => {
  if (app) await app.close();
  await fs.rm(uploadDir, { recursive: true, force: true });
});

async function login(phone: string): Promise<{ accessToken: string; refreshToken: string }> {
  const response = await api("POST", "/v1/auth/verify", { body: { phone, code: "123456" } });
  assert.equal(response.status, 201, JSON.stringify(response.json));
  return response.json;
}

async function signup(
  phone: string,
  body: Record<string, unknown>,
): Promise<{ status: number; json: { code?: string } }> {
  const session = await login(phone);
  return api("PUT", "/v1/me", { token: session.accessToken, body });
}

async function readyUser(
  phone: string,
  name: string,
  gender: string,
  show: string[],
  location?: { latitude: number; longitude: number },
): Promise<{ id: string; token: string }> {
  const session = await login(phone);
  const saved = await api("PUT", "/v1/me", { token: session.accessToken, body: profileBody(name, gender, show) });
  assert.equal(saved.status, 200, JSON.stringify(saved.json));
  const jpeg = await sharp({
    create: { width: 32, height: 40, channels: 3, background: { r: 180, g: 40, b: 70 } },
  })
    .jpeg()
    .toBuffer();
  assert.equal((await upload(session.accessToken, jpeg)).status, 201);
  assert.equal((await upload(session.accessToken, jpeg)).status, 201);
  if (location) {
    const placed = await api("POST", "/v1/me/location", { token: session.accessToken, body: location });
    assert.equal(placed.status, 201);
  }
  const me = await api("GET", "/v1/me", { token: session.accessToken });
  assert.equal(me.json.onboardingComplete, true);
  return { id: me.json.id as string, token: session.accessToken };
}

function profileBody(name: string, gender: string, show: string[], extra: Record<string, unknown> = {}) {
  return {
    displayName: name,
    birthDate: "1996-06-01",
    gender,
    showGenders: show,
    cityId: TEHRAN_ID,
    bio: "سلام از تهران",
    ...extra,
  };
}

async function upload(token: string, bytes: Buffer): Promise<{ status: number; json: { id: string } }> {
  const form = new FormData();
  form.append("file", new Blob([new Uint8Array(bytes)], { type: "image/jpeg" }), "photo.jpg");
  const response = await fetch(`${base}/v1/me/photos`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  const json = (await response.json()) as { id: string };
  return { status: response.status, json };
}

function withMarker(jpeg: Buffer, marker: string): Buffer {
  const payload = Buffer.from(marker);
  const length = payload.length + 2;
  const comment = Buffer.concat([Buffer.from([0xff, 0xfe, (length >> 8) & 0xff, length & 0xff]), payload]);
  return Buffer.concat([jpeg.subarray(0, 2), comment, jpeg.subarray(2)]);
}

async function api(
  method: string,
  urlPath: string,
  options: { token?: string; body?: unknown } = {},
): Promise<{ status: number; json: any }> {
  const response = await fetch(`${base}${urlPath}`, {
    method,
    headers: {
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
      ...(options.body ? { "Content-Type": "application/json" } : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  return { status: response.status, json };
}
