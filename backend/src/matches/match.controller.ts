import { Body, Controller, Get, Inject, Param, Post, UseGuards } from "@nestjs/common";
import { IsString, MaxLength } from "class-validator";
import { AuthGuard } from "../auth/auth.guard";
import { CurrentUser } from "../auth/current-user.decorator";
import { MatchService } from "./match.service";

class MessageDto {
  @IsString()
  @MaxLength(1000)
  body!: string;
}

@Controller("matches")
@UseGuards(AuthGuard)
export class MatchController {
  constructor(@Inject(MatchService) private readonly matches: MatchService) {}

  @Get()
  list(@CurrentUser() userId: string) {
    return this.matches.list(userId);
  }

  @Get(":id/messages")
  messages(@CurrentUser() userId: string, @Param("id") id: string) {
    return this.matches.messages(userId, id);
  }

  @Post(":id/messages")
  send(@CurrentUser() userId: string, @Param("id") id: string, @Body() body: MessageDto) {
    return this.matches.send(userId, id, body.body);
  }

  @Post(":id/unmatch")
  unmatch(@CurrentUser() userId: string, @Param("id") id: string) {
    return this.matches.unmatch(userId, id);
  }
}
