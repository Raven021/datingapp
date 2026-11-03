import { Inject, Injectable } from "@nestjs/common";
import { AppError } from "../common/errors";
import { normalizePhone } from "../common/phone";
import { hashPhone } from "../auth/auth.service";
import { PrismaService } from "../prisma/prisma.service";

@Injectable()
export class SafetyService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async blockUser(blockerId: string, blockedUserId: string) {
    if (blockerId === blockedUserId) throw new AppError("VALIDATION", "نمی‌توانی خودت را مسدود کنی.");
    const blocked = await this.prisma.user.findUnique({ where: { id: blockedUserId } });
    if (!blocked) throw new AppError("NOT_FOUND", "کاربر پیدا نشد.", 404);
    await this.prisma.block.create({
      data: { blockerId, blockedUserId, phoneHash: blocked.phoneHash },
    });
    await this.closeMatch(blockerId, blockedUserId);
    return { ok: true };
  }

  async blockPhone(blockerId: string, rawPhone: string) {
    const phone = normalizePhone(rawPhone);
    if (!phone) throw new AppError("INVALID_PHONE", "شماره موبایل درست نیست.");
    const phoneHash = hashPhone(phone);
    const existing = await this.prisma.user.findUnique({ where: { phoneHash } });
    await this.prisma.block.create({
      data: { blockerId, blockedUserId: existing && !existing.deletedAt ? existing.id : null, phoneHash },
    });
    if (existing) await this.closeMatch(blockerId, existing.id);
    return { ok: true };
  }

  async report(reporterId: string, reportedUserId: string, reason: string) {
    const trimmed = reason.trim();
    if (trimmed.length < 2) throw new AppError("VALIDATION", "دلیل گزارش را بنویس.");
    await this.prisma.report.create({ data: { reporterId, reportedUserId, reason: trimmed.slice(0, 300) } });
    await this.blockUser(reporterId, reportedUserId);
    return { ok: true };
  }

  private async closeMatch(a: string, b: string) {
    const [low, high] = a < b ? [a, b] : [b, a];
    await this.prisma.match.updateMany({
      where: { userLowId: low, userHighId: high, status: { not: "closed" } },
      data: { status: "closed", closedAt: new Date() },
    });
  }
}
