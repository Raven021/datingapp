import { Inject, Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { AppError } from "../common/errors";
import { mediaUrl } from "../profile/profile.service";
import { PrismaService } from "../prisma/prisma.service";

type DeckRow = {
  user_id: string;
  display_name: string;
  age: number;
  gender: string;
  bio: string;
  job: string | null;
  education: string | null;
  city_name: string;
  distance_km: number | null;
};

@Injectable()
export class DiscoveryService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async deck(userId: string, limit = 20) {
    const me = await this.prisma.profile.findUnique({ where: { userId } });
    const preference = await this.prisma.preference.findUnique({ where: { userId } });
    if (!me?.onboardingComplete || !preference) {
      throw new AppError("ONBOARDING_INCOMPLETE", "اول پروفایلت را کامل کن.");
    }
    await this.prisma.profile.update({ where: { userId }, data: { lastActiveAt: new Date() } });
    const hasLocation = me.latitude !== null && me.longitude !== null;
    const rows = await this.prisma.$queryRaw<DeckRow[]>(Prisma.sql`
      SELECT
        c.user_id,
        c.display_name,
        EXTRACT(YEAR FROM age(current_date, c.birth_date))::int AS age,
        c.gender,
        c.bio,
        c.job,
        c.education,
        city.name_fa AS city_name,
        CASE
          WHEN CAST(${hasLocation} AS boolean) AND c.latitude IS NOT NULL AND c.longitude IS NOT NULL THEN
            ROUND(ST_DistanceSphere(
              ST_MakePoint(c.longitude, c.latitude),
              ST_MakePoint(${me.longitude ?? 0}, ${me.latitude ?? 0})
            ) / 1000.0)::int
          ELSE NULL
        END AS distance_km,
        EXISTS (
          SELECT 1 FROM swipes incoming
          WHERE incoming.from_user_id = c.user_id
            AND incoming.to_user_id = CAST(${userId} AS uuid)
            AND incoming.direction = 'like'
        ) AS liked_me,
        CASE
          WHEN COALESCE(stats.shows, 0) < 8 THEN 0.2
          ELSE (COALESCE(stats.likes, 0) + 2.0) / (COALESCE(stats.shows, 0) + 10.0)
        END AS rate
      FROM profiles c
      JOIN users cu ON cu.id = c.user_id
      JOIN preferences cp ON cp.user_id = c.user_id
      JOIN cities city ON city.id = c.city_id
      JOIN profiles me ON me.user_id = CAST(${userId} AS uuid)
      JOIN preferences mypref ON mypref.user_id = me.user_id
      LEFT JOIN LATERAL (
        SELECT
          (SELECT COUNT(*)::int FROM impressions i WHERE i.shown_user_id = c.user_id) AS shows,
          (SELECT COUNT(*)::int FROM swipes s WHERE s.to_user_id = c.user_id AND s.direction = 'like') AS likes
      ) stats ON true
      WHERE cu.deleted_at IS NULL
        AND c.onboarding_complete = true
        AND c.user_id <> me.user_id
        AND c.gender = ANY(mypref.show_genders)
        AND me.gender = ANY(cp.show_genders)
        AND EXTRACT(YEAR FROM age(current_date, c.birth_date))::int BETWEEN mypref.age_min AND mypref.age_max
        AND EXTRACT(YEAR FROM age(current_date, me.birth_date))::int BETWEEN cp.age_min AND cp.age_max
        AND NOT EXISTS (
          SELECT 1 FROM swipes seen
          WHERE seen.from_user_id = me.user_id AND seen.to_user_id = c.user_id
        )
        AND NOT EXISTS (
          SELECT 1 FROM blocks b
          WHERE (b.blocker_id = me.user_id AND (b.blocked_user_id = c.user_id OR b.phone_hash = cu.phone_hash))
             OR (b.blocker_id = c.user_id AND (
               b.blocked_user_id = me.user_id
               OR b.phone_hash = (SELECT phone_hash FROM users WHERE id = me.user_id)
             ))
        )
        AND (
          (
            CAST(${hasLocation} AS boolean)
            AND c.latitude IS NOT NULL
            AND ST_DistanceSphere(ST_MakePoint(c.longitude, c.latitude), ST_MakePoint(${me.longitude ?? 0}, ${me.latitude ?? 0}))
                <= mypref.max_distance_km * 1000
            AND ST_DistanceSphere(ST_MakePoint(c.longitude, c.latitude), ST_MakePoint(${me.longitude ?? 0}, ${me.latitude ?? 0}))
                <= cp.max_distance_km * 1000
          )
          OR (CAST(${hasLocation} AS boolean) AND c.latitude IS NULL AND c.city_id = me.city_id)
          OR (NOT CAST(${hasLocation} AS boolean) AND c.city_id = me.city_id)
        )
      ORDER BY liked_me DESC, rate DESC, c.last_active_at DESC
      LIMIT ${Math.min(Math.max(limit, 1), 30)}
    `);
    if (rows.length > 0) {
      await this.prisma.impression.createMany({
        data: rows.map((row) => ({ viewerId: userId, shownUserId: row.user_id })),
        skipDuplicates: true,
      });
    }
    const photos = await this.prisma.photo.findMany({
      where: { userId: { in: rows.map((row) => row.user_id) } },
      orderBy: { sortOrder: "asc" },
    });
    return {
      cards: rows.map((row) => ({
        id: row.user_id,
        displayName: row.display_name,
        age: row.age,
        gender: row.gender,
        bio: row.bio,
        job: row.job,
        education: row.education,
        cityName: row.city_name,
        distanceKm: row.distance_km,
        photos: photos.filter((photo) => photo.userId === row.user_id).map((photo) => ({ id: photo.id, url: mediaUrl(photo.id) })),
      })),
    };
  }
}
