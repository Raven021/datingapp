import { Module } from "@nestjs/common";
import { AuthModule } from "./auth/auth.module";
import { DiscoveryController } from "./discovery/discovery.controller";
import { DiscoveryService } from "./discovery/discovery.service";
import { HealthController } from "./health.controller";
import { MatchController } from "./matches/match.controller";
import { MatchService } from "./matches/match.service";
import { MediaController } from "./media/media.controller";
import { MediaService } from "./media/media.service";
import { Notifier } from "./notify/notifier";
import { PrismaModule } from "./prisma/prisma.module";
import { ProfileController } from "./profile/profile.controller";
import { ProfileService } from "./profile/profile.service";
import { RedisModule } from "./redis/redis.module";
import { SafetyController } from "./safety/safety.controller";
import { SafetyService } from "./safety/safety.service";
import { SwipeController } from "./swipes/swipe.controller";
import { SwipeService } from "./swipes/swipe.service";

@Module({
  imports: [PrismaModule, RedisModule, AuthModule],
  controllers: [
    HealthController,
    ProfileController,
    MediaController,
    DiscoveryController,
    SwipeController,
    MatchController,
    SafetyController,
  ],
  providers: [ProfileService, MediaService, DiscoveryService, SwipeService, MatchService, SafetyService, Notifier],
})
export class AppModule {}
