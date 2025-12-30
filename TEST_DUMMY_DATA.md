# Setup Dummy Data Test

This test creates comprehensive dummy data for testing:
- **10 dummy users** without email validation
- **2 groups** with members
- **2 games** (one in each group) with participants and transactions

## Requirements

1. Update your `env.json` file in the project root with your Supabase admin credentials:
```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key",
  "SUPABASE_SERVICE_KEY": "your-service-role-key"
}
```

⚠️ **Important:** The `SUPABASE_SERVICE_KEY` is sensitive. Never commit it to version control. Add it only for local testing.

## Running the Test

```bash
flutter test test/setup_dummy_data_test.dart -r compact
```

## What Gets Created

### Users (10 total)
- `dummy_user_1` through `dummy_user_10`
- Email format: `user1@dummy.test`, `user2@dummy.test`, etc.
- All users get a profile with name, username, and country set

### Groups (2 total)
**Group 1: Test Poker Group 1**
- Creator: user 1
- Members: users 1-5 (user 1 is admin, others are members)
- Privacy: Private
- Currency: USD
- Default buy-in: $100, Additional: $50

**Group 2: Test Poker Group 2**
- Creator: user 6
- Members: users 6-10 (user 6 is admin, others are members)
- Privacy: Public
- Currency: USD
- Default buy-in: $50, Additional: $25

### Games (2 total)
**Game 1: Group 1**
- 5 participants
- Buy-ins: $100 or $200
- Cash-outs: $75 or $350
- Status: Completed
- Transactions: Buy-in and cash-out for each participant

**Game 2: Group 2**
- 5 participants
- Buy-ins: $50 each
- Cash-outs: $120 or $20 (alternating wins/losses)
- Status: Completed
- Transactions: Buy-in and cash-out for each participant

## Accessing the Data

Once the test runs successfully, you can:
1. View the data in your Supabase dashboard
2. Sign in to the app with any dummy user (though note: email verification will likely be required in production)
3. Test group and game functionality with pre-populated data

## Notes

- IDs are generated with timestamps to ensure uniqueness across multiple test runs
- The test directly inserts into the database (bypassing normal auth flows)
- All timestamps use the current time (can be adjusted in the test)
- Transactions are created with a 2-3 hour gap to simulate realistic game flow
