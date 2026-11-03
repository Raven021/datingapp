import { IsArray, IsInt, IsNumber, IsOptional, IsString, Max, MaxLength, Min, MinLength } from "class-validator";

export class UpsertProfileDto {
  @IsString()
  @MinLength(2)
  @MaxLength(40)
  displayName!: string;

  @IsString()
  birthDate!: string;

  @IsString()
  gender!: string;

  @IsArray()
  @IsString({ each: true })
  showGenders!: string[];

  @IsString()
  cityId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  bio?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  job?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  education?: string;

  @IsOptional()
  @IsInt()
  @Min(18)
  @Max(80)
  ageMin?: number;

  @IsOptional()
  @IsInt()
  @Min(18)
  @Max(80)
  ageMax?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(150)
  maxDistanceKm?: number;
}

export class LocationDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;
}

export class PhotoOrderDto {
  @IsArray()
  @IsString({ each: true })
  ids!: string[];
}

export class DeviceDto {
  @IsString()
  @MinLength(8)
  token!: string;

  @IsString()
  platform!: string;
}
