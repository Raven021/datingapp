import { Inject, Injectable } from "@nestjs/common";
import fs from "fs/promises";
import path from "path";
import { Prisma } from "@prisma/client";
import { ageOn, isAdult } from "../common/age";
import { AppError } from "../common/errors";
import { isGender } from "../common/genders";
import { required } from "../load-env";
import { PrismaService } from "../prisma/prisma.service";
import { UpsertProfileDto } from "./profile.dto";

@Injectable()
export class ProfileService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async cities() {
    const rows = await this.prisma.city.findMany();
    return rows
      .map(({ id, nameFa }) => ({ id, nameFa }))
      .sort((a, b) => a.nameFa.localeCompare(b.nameFa, "fa"));
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: { include: { city: true } }, preference: true, photos: { orderBy: { sortOrder: "asc" } } },
    });
    if (!user || user.deletedAt) throw new AppError("NOT_FOUND", "حساب پیدا نشد.", 404);
    return {
      id: user.id,
      phone: user.phoneE164,
      onboardingComplete: user.profile?.onboardingComplete ?? false,
      profile: user.profile
        ? {
            displayName: user.profile.displayName,
            birthDate: user.profile.birthDate.toISOString().slice(0, 10),
            age: ageOn(user.profile.birthDate),
            gender: user.profile.gender,
            bio: user.profile.bio,
            job: user.profile.job,
            education: user.profile.education,
            cityId: user.profile.cityId,
            cityName: user.profile.city.nameFa,
            hasLocation: user.profile.latitude !== null,
            showGenders: user.preference?.showGenders ?? [],
            ageMin: user.preference?.ageMin ?? 18,
            ageMax: user.preference?.ageMax ?? 80,
            maxDistanceKm: user.preference?.maxDistanceKm ?? 50,
            photos: user.photos.map((photo) => ({
              id: photo.id,
              url: mediaUrl(photo.id),
            })),
          }
        : null,
    };
  }

  async save(userId: string, input: UpsertProfileDto) {
    if (!isGender(input.gender)) throw new AppError("VALIDATION", "جنسیت را انتخاب کن.");
    const showGenders = [...new Set(input.showGenders)];
    if (showGenders.length === 0 || showGenders.some((gender) => !isGender(gender))) {
      throw new AppError("VALIDATION", "بگو چه کسانی را می‌خواهی ببینی.");
    }
    const birthDate = new Date(`${input.birthDate}T00:00:00.000Z`);
    if (Number.isNaN(birthDate.getTime())) throw new AppError("VALIDATION", "تاریخ تولد درست نیست.");
    if (!isAdult(birthDate)) throw new AppError("UNDERAGE", "برای ساخت حساب باید حداقل ۱۸ سال داشته باشی.");
    const city = await this.prisma.city.findUnique({ where: { id: input.cityId } });
    if (!city) throw new AppError("VALIDATION", "شهر را انتخاب کن.");
    const ageMin = input.ageMin ?? 18;
    const ageMax = input.ageMax ?? 80;
    if (ageMin > ageMax) throw new AppError("VALIDATION", "بازه سنی درست نیست.");
    const photoCount = await this.prisma.photo.count({ where: { userId } });
    const onboardingComplete = photoCount >= 2;
    await this.prisma.profile.upsert({
      where: { userId },
      create: {
        userId,
        displayName: input.displayName.trim(),
        birthDate,
        gender: input.gender,
        bio: input.bio?.trim() ?? "",
        job: blankToNull(input.job),
        education: blankToNull(input.education),
        cityId: input.cityId,
        onboardingComplete,
      },
      update: {
        displayName: input.displayName.trim(),
        birthDate,
        gender: input.gender,
        bio: input.bio?.trim() ?? "",
        job: blankToNull(input.job),
        education: blankToNull(input.education),
        cityId: input.cityId,
        onboardingComplete,
      },
    });
    await this.prisma.preference.upsert({
      where: { userId },
      create: {
        userId,
        showGenders,
        ageMin,
        ageMax,
        maxDistanceKm: input.maxDistanceKm ?? 50,
      },
      update: {
        showGenders,
        ageMin,
        ageMax,
        maxDistanceKm: input.maxDistanceKm ?? 50,
      },
    });
    return this.me(userId);
  }

  async setLocation(userId: string, latitude: number, longitude: number) {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new AppError("ONBOARDING_INCOMPLETE", "اول پروفایلت را کامل کن.");
    await this.prisma.profile.update({
      where: { userId },
      data: { latitude, longitude },
    });
    return { ok: true };
  }

  async clearLocation(userId: string) {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new AppError("ONBOARDING_INCOMPLETE", "اول پروفایلت را کامل کن.");
    await this.prisma.profile.update({
      where: { userId },
      data: { latitude: null, longitude: null },
    });
    return { ok: true };
  }

  async saveDevice(userId: string, token: string, platform: string) {
    await this.prisma.device.upsert({
      where: { userId_token: { userId, token } },
      create: { userId, token, platform },
      update: { platform },
    });
    return { ok: true };
  }

  async remove(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.deletedAt) return { ok: true };
    await this.prisma.$transaction(async (tx) => {
      await tx.block.updateMany({
        where: { blockedUserId: userId, phoneHash: null },
        data: { phoneHash: user.phoneHash },
      });
      await tx.photo.deleteMany({ where: { userId } });
      await tx.match.updateMany({
        where: { status: { not: "closed" }, OR: [{ userLowId: userId }, { userHighId: userId }] },
        data: { status: "closed", closedAt: new Date() },
      });
      await tx.user.update({
        where: { id: userId },
        data: {
          deletedAt: new Date(),
          phoneE164: `deleted:${userId}`,
          phoneHash: `deleted:${userId}`,
        },
      });
      await tx.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    });
    await fs.rm(path.join(path.resolve(required("UPLOAD_DIR")), userId), { recursive: true, force: true });
    return { ok: true };
  }
}

export function mediaUrl(photoId: string): string {
  return `${required("PUBLIC_BASE_URL").replace(/\/$/, "")}/v1/media/${photoId}`;
}

function blankToNull(value: string | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

export type ProfileRecord = Prisma.ProfileGetPayload<{ include: { city: true } }>;
