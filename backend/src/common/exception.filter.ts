import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from "@nestjs/common";
import { Response } from "express";
import { AppError } from "./errors";

@Catch()
export class AppExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    if (exception instanceof AppError) {
      response.status(exception.getStatus()).json(exception.getResponse());
      return;
    }
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      if (status === 400) {
        response.status(400).json({ code: "VALIDATION", message: "اطلاعات واردشده درست نیست." });
        return;
      }
      if (status === 401) {
        response.status(401).json({ code: "UNAUTHORIZED", message: "وارد حسابت شو." });
        return;
      }
      response.status(status).json({ code: "ERROR", message: "درخواست انجام نشد." });
      return;
    }
    console.error(exception);
    response.status(500).json({ code: "ERROR", message: "خطای سرور." });
  }
}
