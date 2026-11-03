import "reflect-metadata";
import fs from "fs/promises";
import path from "path";
import { PrismaClient } from "@prisma/client";
import sharp from "sharp";
import { hashPhone } from "../src/auth/auth.service";
import { loadEnv } from "../src/load-env";
import { CITIES, TEHRAN_ID } from "./cities";

export const TINA_ID = "10000000-0000-4000-8000-000000000001";
export const ARMAN_ID = "10000000-0000-4000-8000-000000000002";
export const REZA_ID = "10000000-0000-4000-8000-000000000003";
export const KIAN_ID = "10000000-0000-4000-8000-000000000004";

const WOMEN = [
  { id: "10000000-0000-4000-8000-000000000005", name: "سارا", phone: "+989120000005", color: [214, 96, 112] },
  { id: "10000000-0000-4000-8000-000000000006", name: "نازنین", phone: "+989120000006", color: [92, 122, 168] },
  { id: "10000000-0000-4000-8000-000000000007", name: "مریم", phone: "+989120000007", color: [196, 142, 74] },
  { id: "10000000-0000-4000-8000-000000000008", name: "هستی", phone: "+989120000008", color: [112, 146, 98] },
  { id: "10000000-0000-4000-8000-000000000009", name: "لیلا", phone: "+989120000009", color: [168, 92, 132] },
  { id: "10000000-0000-4000-8000-00000000000a", name: "نگین", phone: "+989120000010", color: [72, 132, 140] },
  { id: "10000000-0000-4000-8000-00000000000b", name: "پریسا", phone: "+989120000011", color: [176, 112, 72] },
  { id: "10000000-0000-4000-8000-00000000000c", name: "النا", phone: "+989120000012", color: [120, 96, 168] },
] as const;

type Person = {
  id: string;
  phone: string;
  name: string;
  gender: "woman" | "man";
  show: Array<"woman" | "man" | "nonbinary">;
  birthDate: string;
  bio: string;
  job?: string;
  education?: string;
  color: readonly [number, number, number];
  lastActiveAt: Date;
};

export async function seedDemo(prisma: PrismaClient, uploadDir: string): Promise<void> {
  for (const city of CITIES) {
    await prisma.city.upsert({
      where: { id: city.id },
      create: { ...city },
      update: { nameFa: city.nameFa, latitude: city.latitude, longitude: city.longitude },
    });
  }

  const people: Person[] = [
    {
      id: TINA_ID,
      phone: "+989120000001",
      name: "تینا",
      gender: "woman",
      show: ["man"],
      birthDate: "1998-05-12",
      bio: "چای و پیاده‌روی شبانه.",
      job: "طراح",
      education: "دانشگاه تهران",
      color: [196, 78, 92],
      lastActiveAt: new Date(),
    },
    {
      id: ARMAN_ID,
      phone: "+989120000002",
      name: "آرمان",
      gender: "man",
      show: ["woman"],
      birthDate: "1996-03-02",
      bio: "عکاسی و غذای خیابانی.",
      job: "مهندس",
      color: [48, 78, 112],
      lastActiveAt: new Date(),
    },
    {
      id: REZA_ID,
      phone: "+989120000003",
      name: "رضا",
      gender: "man",
      show: ["woman"],
      birthDate: "1997-11-20",
      bio: "کتاب و دوچرخه.",
      education: "شریف",
      color: [90, 110, 84],
      lastActiveAt: new Date(Date.now() - 60 * 60 * 1000),
    },
    {
      id: KIAN_ID,
      phone: "+989120000004",
      name: "کیان",
      gender: "man",
      show: ["woman"],
      birthDate: "1995-01-15",
      bio: "موسیقی زنده.",
      color: [120, 84, 64],
      lastActiveAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
    },
    ...WOMEN.map((woman, index) => ({
      id: woman.id,
      phone: woman.phone,
      name: woman.name,
      gender: "woman" as const,
      show: ["man"] as Array<"woman" | "man" | "nonbinary">,
      birthDate: `199${index % 8}-04-0${(index % 8) + 1}`,
      bio: "اهل تهران.",
      color: woman.color as unknown as readonly [number, number, number],
      lastActiveAt: new Date(Date.now() - index * 60_000),
    })),
  ];

  const ids = people.map((person) => person.id);
  await prisma.message.deleteMany({
    where: { match: { OR: [{ userLowId: { in: ids } }, { userHighId: { in: ids } }] } },
  });
  await prisma.match.deleteMany({ where: { OR: [{ userLowId: { in: ids } }, { userHighId: { in: ids } }] } });
  await prisma.swipe.deleteMany({ where: { OR: [{ fromUserId: { in: ids } }, { toUserId: { in: ids } }] } });
  await prisma.impression.deleteMany({ where: { OR: [{ viewerId: { in: ids } }, { shownUserId: { in: ids } }] } });
  await prisma.block.deleteMany({ where: { OR: [{ blockerId: { in: ids } }, { blockedUserId: { in: ids } }] } });
  await prisma.report.deleteMany({ where: { OR: [{ reporterId: { in: ids } }, { reportedUserId: { in: ids } }] } });
  await prisma.user.deleteMany({ where: { id: { in: ids } } });

  for (const person of people) {
    await prisma.user.create({
      data: {
        id: person.id,
        phoneE164: person.phone,
        phoneHash: hashPhone(person.phone),
        profile: {
          create: {
            displayName: person.name,
            birthDate: new Date(`${person.birthDate}T00:00:00.000Z`),
            gender: person.gender,
            bio: person.bio,
            job: person.job,
            education: person.education,
            cityId: TEHRAN_ID,
            onboardingComplete: true,
            lastActiveAt: person.lastActiveAt,
          },
        },
        preference: {
          create: { showGenders: person.show, ageMin: 18, ageMax: 40, maxDistanceKm: 50 },
        },
      },
    });
    for (let index = 0; index < 2; index += 1) {
      const [red, green, blue] = person.color;
      const photo = await prisma.photo.create({
        data: { userId: person.id, storageKey: "pending", sortOrder: index },
      });
      const storageKey = path.join(person.id, `${photo.id}.jpg`);
      const absolute = path.join(uploadDir, storageKey);
      await fs.mkdir(path.dirname(absolute), { recursive: true });
      const jpeg = await sharp({
        create: {
          width: 80,
          height: 100,
          channels: 3,
          background: { r: Math.min(255, red + index * 20), g: green, b: blue },
        },
      })
        .jpeg()
        .toBuffer();
      await fs.writeFile(absolute, jpeg);
      await prisma.photo.update({ where: { id: photo.id }, data: { storageKey } });
    }
  }

  await prisma.impression.createMany({
    data: WOMEN.map((woman) => ({ viewerId: woman.id, shownUserId: ARMAN_ID })),
  });
  await prisma.swipe.createMany({
    data: [
      ...WOMEN.slice(0, 4).map((woman) => ({ fromUserId: woman.id, toUserId: ARMAN_ID, direction: "like" })),
      { fromUserId: ARMAN_ID, toUserId: TINA_ID, direction: "like" },
      { fromUserId: REZA_ID, toUserId: TINA_ID, direction: "like" },
    ],
  });
}

async function main(): Promise<void> {
  loadEnv(path.join(__dirname, "../.env"));
  const prisma = new PrismaClient();
  const uploadDir = path.resolve(process.env.UPLOAD_DIR || "uploads");
  await seedDemo(prisma, uploadDir);
  await prisma.$disconnect();
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
