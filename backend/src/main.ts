import "reflect-metadata";
import { loadEnv } from "./load-env";
import { createApp } from "./app";

loadEnv();

async function bootstrap(): Promise<void> {
  const app = await createApp();
  await app.listen(Number(process.env.PORT ?? 3000));
}

void bootstrap();
