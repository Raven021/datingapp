import { Controller, Get, Inject, Query, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../auth/auth.guard";
import { CurrentUser } from "../auth/current-user.decorator";
import { DiscoveryService } from "./discovery.service";

@Controller("deck")
@UseGuards(AuthGuard)
export class DiscoveryController {
  constructor(@Inject(DiscoveryService) private readonly discovery: DiscoveryService) {}

  @Get()
  deck(@CurrentUser() userId: string, @Query("limit") limit?: string) {
    const parsed = limit ? Number(limit) : 20;
    return this.discovery.deck(userId, Number.isFinite(parsed) ? parsed : 20);
  }
}
