import { Inject, Injectable, Logger } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";

@Injectable()
export class Notifier {
  private readonly logger = new Logger(Notifier.name);

  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async push(userId: string): Promise<void> {
    const devices = await this.prisma.device.findMany({ where: { userId } });
    if (devices.length === 0) return;
    this.logger.log(`generic push to ${devices.length} device(s) for ${userId}`);
  }
}
