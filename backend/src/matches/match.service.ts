import { Inject, Injectable } from "@nestjs/common";
import { AppError } from "../common/errors";
import { isValidOpener } from "../common/opener";
import { ageOn } from "../common/age";
import { mediaUrl } from "../profile/profile.service";
import { PrismaService } from "../prisma/prisma.service";
import { Notifier } from "../notify/notifier";

@Injectable()
export class MatchService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(Notifier) private readonly notifier: Notifier,
  ) {}

  async list(userId: string) {
    const matches = await this.prisma.match.findMany({
      where: {
        status: { not: "closed" },
        OR: [{ userLowId: userId }, { userHighId: userId }],
      },
      include: { messages: { orderBy: { createdAt: "desc" }, take: 1 } },
      orderBy: { createdAt: "desc" },
    });
    const otherIds = matches.map((match) => (match.userLowId === userId ? match.userHighId : match.userLowId));
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: otherIds } },
      include: { city: true },
    });
    const photos = await this.prisma.photo.findMany({
      where: { userId: { in: otherIds } },
      orderBy: { sortOrder: "asc" },
    });
    const counts = await this.prisma.message.groupBy({
      by: ["matchId", "senderId"],
      where: { matchId: { in: matches.map((match) => match.id) } },
      _count: true,
    });
    return {
      matches: matches.map((match) => {
        const otherId = match.userLowId === userId ? match.userHighId : match.userLowId;
        const profile = profiles.find((item) => item.userId === otherId);
        const mine = counts.find((row) => row.matchId === match.id && row.senderId === userId)?._count ?? 0;
        const theirs = counts.find((row) => row.matchId === match.id && row.senderId === otherId)?._count ?? 0;
        const last = match.messages[0];
        const photo = photos.find((item) => item.userId === otherId);
        return {
          id: match.id,
          status: match.status,
          waitingForReply: mine > 0 && theirs === 0,
          needsReply: theirs > 0 && mine === 0,
          other: profile
            ? {
                id: otherId,
                displayName: profile.displayName,
                age: ageOn(profile.birthDate),
                cityName: profile.city.nameFa,
                photoId: photo?.id ?? null,
                photoUrl: photo ? mediaUrl(photo.id) : null,
              }
            : null,
          lastMessage: last ? { body: last.body, mine: last.senderId === userId, createdAt: last.createdAt.toISOString() } : null,
        };
      }),
    };
  }

  async messages(userId: string, matchId: string) {
    const match = await this.requireParticipant(userId, matchId);
    const otherId = match.userLowId === userId ? match.userHighId : match.userLowId;
    const rows = await this.prisma.message.findMany({ where: { matchId }, orderBy: { createdAt: "asc" } });
    return {
      id: match.id,
      status: match.status,
      otherId,
      messages: rows.map((row) => ({
        id: row.id,
        body: row.body,
        mine: row.senderId === userId,
        createdAt: row.createdAt.toISOString(),
      })),
    };
  }

  async send(userId: string, matchId: string, body: string) {
    const text = body.trim();
    if (!text || text.length > 1000) throw new AppError("VALIDATION", "پیام خالی است.");
    const match = await this.requireParticipant(userId, matchId);
    if (match.status === "closed") throw new AppError("MATCH_CLOSED", "این گفتگو بسته شده.");
    const otherId = match.userLowId === userId ? match.userHighId : match.userLowId;
    const result = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.message.findMany({ where: { matchId } });
      const mine = existing.filter((row) => row.senderId === userId).length;
      const theirs = existing.filter((row) => row.senderId === otherId).length;
      if (mine > 0 && theirs === 0) throw new AppError("WAITING_FOR_REPLY", "تا وقتی جواب ندهد پیام دیگری نمی‌توانی بفرستی.");
      if (mine === 0 && theirs === 0 && !isValidOpener(text)) {
        throw new AppError("OPENER_TOO_SHORT", "پیام اول باید حداقل دو کلمه باشد.");
      }
      const message = await tx.message.create({ data: { matchId, senderId: userId, body: text } });
      const unlocks = theirs > 0 && mine === 0;
      if (unlocks) await tx.match.update({ where: { id: matchId }, data: { status: "active" } });
      return message;
    });
    await this.notifier.push(otherId);
    return {
      id: result.id,
      body: result.body,
      mine: true,
      createdAt: result.createdAt.toISOString(),
    };
  }

  async unmatch(userId: string, matchId: string) {
    await this.requireParticipant(userId, matchId);
    await this.prisma.match.update({
      where: { id: matchId },
      data: { status: "closed", closedAt: new Date() },
    });
    return { ok: true };
  }

  private async requireParticipant(userId: string, matchId: string) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match || (match.userLowId !== userId && match.userHighId !== userId)) {
      throw new AppError("NOT_FOUND", "گفتگو پیدا نشد.", 404);
    }
    return match;
  }
}
