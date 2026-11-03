import { Body, Controller, Delete, Get, Inject, Post, Put, UseGuards } from "@nestjs/common";
import { AuthGuard } from "../auth/auth.guard";
import { CurrentUser } from "../auth/current-user.decorator";
import { DeviceDto, LocationDto, UpsertProfileDto } from "./profile.dto";
import { ProfileService } from "./profile.service";

@Controller()
@UseGuards(AuthGuard)
export class ProfileController {
  constructor(@Inject(ProfileService) private readonly profiles: ProfileService) {}

  @Get("cities")
  cities() {
    return this.profiles.cities();
  }

  @Get("me")
  me(@CurrentUser() userId: string) {
    return this.profiles.me(userId);
  }

  @Put("me")
  save(@CurrentUser() userId: string, @Body() body: UpsertProfileDto) {
    return this.profiles.save(userId, body);
  }

  @Post("me/location")
  setLocation(@CurrentUser() userId: string, @Body() body: LocationDto) {
    return this.profiles.setLocation(userId, body.latitude, body.longitude);
  }

  @Delete("me/location")
  clearLocation(@CurrentUser() userId: string) {
    return this.profiles.clearLocation(userId);
  }

  @Post("me/device")
  device(@CurrentUser() userId: string, @Body() body: DeviceDto) {
    return this.profiles.saveDevice(userId, body.token, body.platform);
  }

  @Delete("me")
  remove(@CurrentUser() userId: string) {
    return this.profiles.remove(userId);
  }
}
