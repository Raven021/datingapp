import { HttpException } from "@nestjs/common";

export class AppError extends HttpException {
  constructor(code: string, message: string, status = 400) {
    super({ code, message }, status);
  }
}
