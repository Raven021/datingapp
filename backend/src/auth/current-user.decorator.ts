import { createParamDecorator, ExecutionContext } from "@nestjs/common";
import { AuthedRequest } from "./auth.guard";

export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext) => {
  return ctx.switchToHttp().getRequest<AuthedRequest>().userId;
});
