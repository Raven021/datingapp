import { Inject, Injectable } from "@nestjs/common";
import { createHash, randomInt } from "crypto";
import jwt from "jsonwebtoken";
import { AppError } from "../common/errors";
import { normalizePhone } from "../common/phone";
import { required } from "../load-env";
import { PrismaService } from "../prisma/prisma.service";
import { RedisService } from "../redis/redis.service";

const ACCESS_TTL = "15m";
const REFRESH_DAYS = 30;

@Injectable()
export class AuthService {
  constructor(
    @Inject(PrismaService) private readonly prisma: PrismaService,
    @Inject(RedisService) private readonly redis: RedisService,
  ) {}

  async requestOtp(rawPhone: string): Promise<{ devCode?: string }> {
    const phone = normalizePhone(rawPhone);
    if (!phone) throw new AppError("INVALID_PHONE", "شماره موبایل درست نیست.");
    const recent = await this.redis.set(`otp:lock:${phone}`, "1", "EX", 30, "NX");
    if (recent !== "OK") throw new AppError("OTP_RATE", "چند ثانیه دیگر دوباره کد بگیر.", 429);
    const hourKey = `otp:hour:${phone}`;
    const sent = await this.redis.incr(hourKey);
    if (sent === 1) await this.redis.expire(hourKey, 60 * 60);
    if (sent > 5) throw new AppError("OTP_RATE", "تعداد درخواست کد زیاد شده. یک ساعت دیگر امتحان کن.", 429);
    const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
    await this.redis.set(`otp:${phone}`, code, "EX", 120);
    const devCode = process.env.OTP_DEV_CODE;
    return devCode ? { devCode } : {};
  }

  async verify(rawPhone: string, code: string): Promise<{ accessToken: string; refreshToken: string; onboardingComplete: boolean }> {
    const phone = normalizePhone(rawPhone);
    if (!phone) throw new AppError("INVALID_PHONE", "شماره موبایل درست نیست.");
    const stored = await this.redis.get(`otp:${phone}`);
    const devCode = process.env.OTP_DEV_CODE;
    const matches = code === stored || (devCode !== undefined && devCode !== "" && code === devCode);
    if (!matches) throw new AppError("OTP_INVALID", "کد وارد شده درست نیست.", 401);
    await this.redis.del(`otp:${phone}`);
    const phoneHash = hashPhone(phone);
    let user = await this.prisma.user.findUnique({ where: { phoneHash }, include: { profile: true } });
    if (user?.deletedAt) user = null;
    if (!user) {
      user = await this.prisma.user.create({
        data: { phoneE164: phone, phoneHash },
        include: { profile: true },
      });
    }
    const tokens = await this.issue(user.id);
    return { ...tokens, onboardingComplete: user.profile?.onboardingComplete ?? false };
  }

  async refresh(refreshToken: string): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = this.readRefresh(refreshToken);
    const tokenHash = sha(refreshToken);
    const row = await this.prisma.refreshToken.findUnique({ where: { tokenHash } });
    if (!row || row.revokedAt || row.expiresAt.getTime() < Date.now() || row.userId !== payload.sub) {
      throw new AppError("UNAUTHORIZED", "نشستت تمام شده. دوباره وارد شو.", 401);
    }
    await this.prisma.refreshToken.update({ where: { id: row.id }, data: { revokedAt: new Date() } });
    return this.issue(row.userId);
  }

  async logout(refreshToken: string): Promise<void> {
    const tokenHash = sha(refreshToken);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async issue(userId: string): Promise<{ accessToken: string; refreshToken: string }> {
    const accessToken = jwt.sign({ sub: userId, type: "access" }, required("JWT_ACCESS_SECRET"), { expiresIn: ACCESS_TTL });
    const refreshToken = jwt.sign({ sub: userId, type: "refresh" }, required("JWT_REFRESH_SECRET"), { expiresIn: `${REFRESH_DAYS}d` });
    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: sha(refreshToken),
        expiresAt: new Date(Date.now() + REFRESH_DAYS * 24 * 60 * 60 * 1000),
      },
    });
    return { accessToken, refreshToken };
  }

  private readRefresh(token: string): { sub: string } {
    try {
      const payload = jwt.verify(token, required("JWT_REFRESH_SECRET")) as { sub?: string; type?: string };
      if (!payload.sub || payload.type !== "refresh") throw new Error("bad");
      return { sub: payload.sub };
    } catch {
      throw new AppError("UNAUTHORIZED", "نشستت تمام شده. دوباره وارد شو.", 401);
    }
  }
}

export function hashPhone(phone: string): string {
  return sha(`${required("PHONE_HASH_PEPPER")}:${phone}`);
}

function sha(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}
