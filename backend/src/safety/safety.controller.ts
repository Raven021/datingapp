import { Body, Controller, Inject, Post, UseGuards } from "@nestjs/common";
import { IsOptional, IsString, IsUUID, MaxLength, MinLength } from "class-validator";
import { AuthGuard } from "../auth/auth.guard";
import { CurrentUser } from "../auth/current-user.decorator";
import { AppError } from "../common/errors";
import { SafetyService } from "./safety.service";

class BlockDto {
  @IsOptional()
  @IsUUID()
  userId?: string;

  @IsOptional()
  @IsString()
  phone?: string;
}

class ReportDto {
  @IsUUID()
  userId!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(300)
  reason!: string;
}

@Controller()
@UseGuards(AuthGuard)
export class SafetyController {
  constructor(@Inject(SafetyService) private readonly safety: SafetyService) {}

  @Post("blocks")
  block(@CurrentUser() userId: string, @Body() body: BlockDto) {
    if (body.userId) return this.safety.blockUser(userId, body.userId);
    if (body.phone) return this.safety.blockPhone(userId, body.phone);
    throw new AppError("VALIDATION", "کاربر یا شماره را مشخص کن.");
  }

  @Post("reports")
  report(@CurrentUser() userId: string, @Body() body: ReportDto) {
    return this.safety.report(userId, body.userId, body.reason);
  }
}
