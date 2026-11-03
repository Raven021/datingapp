import { CanActivate, ExecutionContext, Inject, Injectable } from "@nestjs/common";
import { Request } from "express";
import jwt from "jsonwebtoken";
import { AppError } from "../common/errors";
import { required } from "../load-env";
import { PrismaService } from "../prisma/prisma.service";

export type AuthedRequest = Request & { userId: string };

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    const header = request.headers.authorization ?? "";
    const queryToken = typeof request.query.access_token === "string" ? request.query.access_token : "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : queryToken;
    if (!token) throw new AppError("UNAUTHORIZED", "وارد حسابت شو.", 401);
    try {
      const payload = jwt.verify(token, required("JWT_ACCESS_SECRET")) as { sub?: string; type?: string };
      if (!payload.sub || payload.type !== "access") throw new Error("bad token");
      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user || user.deletedAt) throw new Error("gone");
      request.userId = payload.sub;
      return true;
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError("UNAUTHORIZED", "نشستت تمام شده. دوباره وارد شو.", 401);
    }
  }
}
