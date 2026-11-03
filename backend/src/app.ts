import "reflect-metadata";
import { INestApplication, ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import { AppError } from "./common/errors";
import { AppExceptionFilter } from "./common/exception.filter";

export async function createApp(silent = false): Promise<INestApplication> {
  const app = await NestFactory.create(AppModule, silent ? { logger: false } : {});
  app.setGlobalPrefix("v1");
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      exceptionFactory: () => new AppError("VALIDATION", "اطلاعات واردشده درست نیست."),
    }),
  );
  app.useGlobalFilters(new AppExceptionFilter());
  app.enableShutdownHooks();
  return app;
}
