import { Inject, Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { AppError } from "../common/errors";
import { PrismaService } from "../prisma/prisma.service";
import { pairIds } from "../matches/pair";

@Injectable()
export class SwipeService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async swipe(userId: string, targetId: string, direction: "like" | "pass") {
    if (userId === targetId) throw new AppError("VALIDATION", "نمی‌توانی روی خودت سوایپ کنی.");
    if (direction !== "like" && direction !== "pass") throw new AppError("VALIDATION", "سوایپ درست نیست.");
    const target = await this.prisma.user.findUnique({ where: { id: targetId } });
    if (!target || target.deletedAt) throw new AppError("NOT_FOUND", "این پروفایل در دسترس نیست.", 404);
    const me = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!me) throw new AppError("NOT_FOUND", "حساب پیدا نشد.", 404);
    const blocked = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: userId, OR: [{ blockedUserId: targetId }, { phoneHash: target.phoneHash }] },
          { blockerId: targetId, OR: [{ blockedUserId: userId }, { phoneHash: me.phoneHash }] },
        ],
      },
    });
    if (blocked) throw new AppError("NOT_FOUND", "این پروفایل در دسترس نیست.", 404);
    try {
      await this.prisma.swipe.create({ data: { fromUserId: userId, toUserId: targetId, direction } });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new AppError("ALREADY_SWIPED", "قبلاً روی این پروفایل تصمیم گرفتی.");
      }
      throw error;
    }
    if (direction !== "like") return { match: null };
    const reciprocal = await this.prisma.swipe.findUnique({
      where: { fromUserId_toUserId: { fromUserId: targetId, toUserId: userId } },
    });
    if (!reciprocal || reciprocal.direction !== "like") return { match: null };
    const [userLowId, userHighId] = pairIds(userId, targetId);
    const match = await this.prisma.match.upsert({
      where: { userLowId_userHighId: { userLowId, userHighId } },
      create: { userLowId, userHighId, status: "pending" },
      update: {},
    });
    if (match.status === "closed") return { match: null };
    return {
      match: {
        id: match.id,
        status: match.status,
      },
    };
  }
}
