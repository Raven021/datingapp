import { Inject, Injectable } from "@nestjs/common";
import fs from "fs/promises";
import path from "path";
import sharp from "sharp";
import { AppError } from "../common/errors";
import { required } from "../load-env";
import { mediaUrl } from "../profile/profile.service";
import { PrismaService } from "../prisma/prisma.service";

const MAX_PHOTOS = 6;

@Injectable()
export class MediaService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async add(userId: string, bytes: Buffer): Promise<{ id: string; url: string }> {
    const count = await this.prisma.photo.count({ where: { userId } });
    if (count >= MAX_PHOTOS) throw new AppError("PHOTO_LIMIT", "بیشتر از ۶ عکس نمی‌توانی بگذاری.");
    let jpeg: Buffer;
    try {
      jpeg = await sharp(bytes, { failOn: "error" })
        .rotate()
        .resize({ width: 1600, height: 1600, fit: "inside", withoutEnlargement: true })
        .jpeg({ quality: 82 })
        .toBuffer();
    } catch {
      throw new AppError("VALIDATION", "این فایل عکس قابل استفاده نیست.");
    }
    const photo = await this.prisma.photo.create({
      data: { userId, storageKey: "pending", sortOrder: count },
    });
    const storageKey = path.join(userId, `${photo.id}.jpg`);
    const absolute = path.join(uploadRoot(), storageKey);
    await fs.mkdir(path.dirname(absolute), { recursive: true });
    await fs.writeFile(absolute, jpeg);
    await this.prisma.photo.update({ where: { id: photo.id }, data: { storageKey } });
    await this.refreshOnboarding(userId);
    return { id: photo.id, url: mediaUrl(photo.id) };
  }

  async remove(userId: string, photoId: string) {
    const photo = await this.prisma.photo.findFirst({ where: { id: photoId, userId } });
    if (!photo) throw new AppError("NOT_FOUND", "عکس پیدا نشد.", 404);
    await fs.rm(path.join(uploadRoot(), photo.storageKey), { force: true });
    await this.prisma.photo.delete({ where: { id: photoId } });
    const remaining = await this.prisma.photo.findMany({ where: { userId }, orderBy: { sortOrder: "asc" } });
    await this.prisma.$transaction(
      remaining.map((item, index) => this.prisma.photo.update({ where: { id: item.id }, data: { sortOrder: index } })),
    );
    await this.refreshOnboarding(userId);
    return { ok: true };
  }

  async reorder(userId: string, ids: string[]) {
    const photos = await this.prisma.photo.findMany({ where: { userId } });
    const known = new Set(photos.map((photo) => photo.id));
    if (ids.length !== photos.length || ids.some((id) => !known.has(id))) {
      throw new AppError("VALIDATION", "ترتیب عکس‌ها درست نیست.");
    }
    await this.prisma.$transaction(
      ids.map((id, index) => this.prisma.photo.update({ where: { id }, data: { sortOrder: index } })),
    );
    return { ok: true };
  }

  async fileForViewer(viewerId: string, photoId: string): Promise<string> {
    const photo = await this.prisma.photo.findUnique({
      where: { id: photoId },
      include: { user: true },
    });
    if (!photo || photo.user.deletedAt) throw new AppError("NOT_FOUND", "عکس پیدا نشد.", 404);
    const viewer = await this.prisma.user.findUnique({ where: { id: viewerId } });
    if (!viewer) throw new AppError("NOT_FOUND", "عکس پیدا نشد.", 404);
    const blocked = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: viewerId, OR: [{ blockedUserId: photo.userId }, { phoneHash: photo.user.phoneHash }] },
          { blockerId: photo.userId, OR: [{ blockedUserId: viewerId }, { phoneHash: viewer.phoneHash }] },
        ],
      },
    });
    if (blocked && photo.userId !== viewerId) throw new AppError("NOT_FOUND", "عکس پیدا نشد.", 404);
    return path.join(uploadRoot(), photo.storageKey);
  }

  private async refreshOnboarding(userId: string) {
    const count = await this.prisma.photo.count({ where: { userId } });
    await this.prisma.profile.updateMany({
      where: { userId },
      data: { onboardingComplete: count >= 2 },
    });
  }
}

export function uploadRoot(): string {
  return path.resolve(required("UPLOAD_DIR"));
}
