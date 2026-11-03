# آشنا

A Farsi, right-to-left dating app for people inside Iran, with one Flutter client and a NestJS API. Mutual like before anyone can message. Either person may send one opener of at least two words; the thread stays locked until the other replies.

This repository is the product itself: the client, the API, and the rules. Store listing stays a separate decision for when a store can carry it.

## Run the API

PostgreSQL 16 needs PostGIS, and Redis needs to be on `127.0.0.1:6379`. On this machine, if the services are installed but not running:

```bash
sudo pg_ctlcluster 16 main start
sudo redis-server --daemonize yes --bind 127.0.0.1 --port 6379
```

`docker-compose.yml` is the same pair of services when Docker is available. Create the app database once if it does not exist, then enable PostGIS:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

```bash
cd backend
cp .env.example .env
npm install
npx prisma db push
npm run seed
npm run dev
```

The API listens on `http://127.0.0.1:3000`. In development the OTP code is `123456` for any valid Iranian mobile. Seeded Tehran accounts:

| Person | Phone | What to expect |
| --- | --- | --- |
| تینا | `09120000001` | First card is آرمان. رضا is also in the deck, after آرمان. |
| آرمان | `09120000002` | Eight shows and four likes, and he already liked تینا. |
| رضا | `09120000003` | No previous likes or shows, and he already liked تینا. |

Incoming likes are sorted first and left unlabeled. After that the order is like-rate `(likes + 2) / (shows + 10)` once someone has 8 unique shows (until then the rate stays at 0.2), then last active.

## Run the app

```bash
export PATH="$HOME/sdk/flutter/bin:$PATH"
cd app
flutter pub get
flutter run
```

Android emulator reaches the API at `http://10.0.2.2:3000`. Other targets use `http://127.0.0.1:3000`. Override with `--dart-define=API_BASE=http://your-host:3000`. Dev builds allow cleartext HTTP to that local API. Photos are loaded from the same host, with the access token, so the phone never needs the server's public URL.

iOS cannot be compiled on Linux. `flutter analyze` and `flutter test` cover the client here. Android cleartext and iOS local networking are enabled for this dev API only.

## Tests

```bash
cd backend && npm test && npm run typecheck
cd app && flutter analyze && flutter test
```

The API suite checks the under-18 rejection, reciprocal match, one-word opener, the locked second message, a short reply that opens the thread, آرمان sorting ahead of رضا with no liked-you field, phone block both ways, mutual distance, and JPEG re-encode stripping a comment marker.

## Product rules in this build

- 18+, woman / man / nonbinary, each person chooses who they see. Both filters have to agree.
- Up to 6 photos, at least 2 before the deck. JPEG re-encode strips EXIF. No blur.
- City is chosen by the person. Phone GPS is optional and is stored only to compute distance. The API returns a rounded kilometre count, «کمتر از ۱ کیلومتر», or the city name, and leaves coordinates out of every response. With GPS off, the pool is the whole city. When both people have a location, both distance caps apply.
- Unlimited likes. A match is two likes. One opener, then the reply unlocks normal text. No 24-hour expiry and no women-must-go-first rule.
- Block by person or by phone hash. A report also blocks. Blocks are silent and work in both directions, including after the other account is deleted.
- Account deletion is required and available in the profile. Push is a generic log-only notifier; the open thread polls.
