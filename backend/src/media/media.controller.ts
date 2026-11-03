import { Body, Controller, Delete, Get, Inject, Param, Post, Put, Res, UploadedFile, UseGuards, UseInterceptors } from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { Response } from "express";
import { memoryStorage } from "multer";
import { AuthGuard } from "../auth/auth.guard";
import { CurrentUser } from "../auth/current-user.decorator";
import { AppError } from "../common/errors";
import { PhotoOrderDto } from "../profile/profile.dto";
import { MediaService } from "./media.service";

@Controller()
@UseGuards(AuthGuard)
export class MediaController {
  constructor(@Inject(MediaService) private readonly media: MediaService) {}

  @Post("me/photos")
  @UseInterceptors(
    FileInterceptor("file", {
      storage: memoryStorage(),
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  add(@CurrentUser() userId: string, @UploadedFile() file?: Express.Multer.File) {
    if (!file?.buffer?.length) throw new AppError("VALIDATION", "عکس را انتخاب کن.");
    return this.media.add(userId, file.buffer);
  }

  @Put("me/photos/order")
  reorder(@CurrentUser() userId: string, @Body() body: PhotoOrderDto) {
    return this.media.reorder(userId, body.ids);
  }

  @Delete("me/photos/:id")
  remove(@CurrentUser() userId: string, @Param("id") id: string) {
    return this.media.remove(userId, id);
  }

  @Get("media/:id")
  async file(@CurrentUser() userId: string, @Param("id") id: string, @Res() response: Response) {
    const file = await this.media.fileForViewer(userId, id);
    response.sendFile(file);
  }
}
