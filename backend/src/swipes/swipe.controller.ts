import { Body, Controller, Inject, Post, UseGuards } from "@nestjs/common";
import { IsIn, IsUUID } from "class-validator";
import { AuthGuard } from "../auth/auth.guard";
import { CurrentUser } from "../auth/current-user.decorator";
import { SwipeService } from "./swipe.service";

class SwipeDto {
  @IsUUID()
  userId!: string;

  @IsIn(["like", "pass"])
  direction!: "like" | "pass";
}

@Controller("swipes")
@UseGuards(AuthGuard)
export class SwipeController {
  constructor(@Inject(SwipeService) private readonly swipes: SwipeService) {}

  @Post()
  swipe(@CurrentUser() userId: string, @Body() body: SwipeDto) {
    return this.swipes.swipe(userId, body.userId, body.direction);
  }
}
