import { Body, Controller, Inject, Post } from "@nestjs/common";
import { IsString, MinLength } from "class-validator";
import { AuthService } from "./auth.service";

class PhoneDto {
  @IsString()
  phone!: string;
}

class VerifyDto {
  @IsString()
  phone!: string;

  @IsString()
  @MinLength(4)
  code!: string;
}

class RefreshDto {
  @IsString()
  refreshToken!: string;
}

@Controller("auth")
export class AuthController {
  constructor(@Inject(AuthService) private readonly auth: AuthService) {}

  @Post("otp")
  requestOtp(@Body() body: PhoneDto) {
    return this.auth.requestOtp(body.phone);
  }

  @Post("verify")
  verify(@Body() body: VerifyDto) {
    return this.auth.verify(body.phone, body.code);
  }

  @Post("refresh")
  refresh(@Body() body: RefreshDto) {
    return this.auth.refresh(body.refreshToken);
  }

  @Post("logout")
  async logout(@Body() body: RefreshDto) {
    await this.auth.logout(body.refreshToken);
    return { ok: true };
  }
}
