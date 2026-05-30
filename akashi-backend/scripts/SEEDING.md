# Demo Seeding

Run the demo seeder from `akashi-backend` after setting `SUPABASE_URL` and `SUPABASE_SERVICE_KEY`:

```bash
python scripts/seed_demo_data.py
```

What it seeds:
- 3 farmer auth users when the Supabase Auth admin API is available
- matching rows in `farmers`
- sample `fields` polygons and crop metadata
- `health_readings` history with green, yellow, and red examples
- `notifications` rows for alert UI testing
- government dashboard users

Test accounts:
- `+8801712345678` - আব্দুল করিম
- `+8801812345678` - রহিমা বেগম
- `+8801912345678` - জামাল উদ্দিন
- `officer@dae.gov.bd` - district officer test user
- `national@dae.gov.bd` - national admin test user

Notes:
- The script is safe to re-run. It updates rows when possible and skips existing readings/notifications.
- If the auth admin call is unavailable, the script still seeds the database rows, but the app-side phone login flow will only work once the matching Supabase auth users exist.
