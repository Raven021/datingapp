import { Injectable, OnModuleDestroy } from "@nestjs/common";
import Redis from "ioredis";
import { required } from "../load-env";

@Injectable()
export class RedisService extends Redis implements OnModuleDestroy {
  constructor() {
    super(required("REDIS_URL"));
  }

  async onModuleDestroy(): Promise<void> {
    await this.quit();
  }
}
