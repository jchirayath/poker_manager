# ⚡ QUICK REFERENCE: Financial Validation

**Status:** ✅ READY | **Deploy:** `supabase db push` | **Test:** `flutter test`

---

## 🔧 What Changed

### Database (016_add_financial_validation_constraints.sql)
```sql
✅ Negative values BLOCKED
✅ Max 2 decimal places ENFORCED
✅ Max transaction: $10,000
✅ Max settlement: $5,000
✅ Audit logging ON
```

### App (Dart Code)
```dart
✅ validateAmount() - Check any amount
✅ roundToCurrency() - Safe rounding
✅ validateTransactionData() - Transaction check
✅ validateSettlementData() - Settlement check
```

---

## 🚨 Validation Rules

| Item | Min | Max | Decimals | Notes |
|------|-----|-----|----------|-------|
| Transaction | $0.01 | $10,000.00 | 2 max | buyin/cashout only |
| Settlement | $0.01 | $5,000.00 | 2 max | payer ≠ payee |
| Buy-in | $0.00 | ∞ | 2 max | cumulative per game |
| Cash-out | $0.00 | ∞ | 2 max | cumulative per game |

---

## ❌ REJECTED Examples

```
-50.00           → "cannot be negative"
50.999           → "2 decimal places"
50000.00         → "exceeds maximum"
type: "payment"  → "buyin/cashout only"
payer == payee   → "must be different"
```

---

## ✅ ACCEPTED Examples

```
0.01             → Valid minimum
50.00            → Valid normal
10000.00         → Valid maximum
50.12            → Valid decimal
```

---

## 🐛 Error Messages Users See

```
"Amount cannot be negative"
"Amount must have at most 2 decimal places"
"Amount exceeds maximum of $10,000.00"
"Payer and payee must be different people"
"Cannot add transactions to completed game"
"Invalid transaction type: must be 'buyin' or 'cashout'"
```

---

## 📊 Files Changed

| File | Lines | Changes |
|------|-------|---------|
| `016_...constraints.sql` | 393 | New: DB constraints |
| `settlements_repository.dart` | 495 | +265 validation |
| `games_repository.dart` | 474 | +85 validation |
| `*.md` docs | 1000+ | New guides |

---

## 🚀 Deploy

```bash
cd /Users/jacobc/code/poker_manager
supabase db push
flutter test
flutter run --dart-define-from-file=env.json
```

---

## 🔍 Verify

```sql
-- Check constraints applied
SELECT constraint_name FROM information_schema.check_constraints 
WHERE table_name IN ('transactions', 'settlements');

-- Check audit log created
SELECT COUNT(*) FROM financial_audit_log;
```

---

## 📚 Full Docs

- `FINANCIAL_VALIDATION_IMPLEMENTATION.md` - Complete guide (500+ lines)
- `SECURITY_FIX_SUMMARY.md` - Deployment guide (400+ lines)
- `IMPLEMENTATION_COMPLETE.md` - Final checklist (300+ lines)

---

## ⏱️ Time to Deploy

1. Apply migration: 30 seconds
2. Run tests: 2 minutes
3. Deploy: 5 minutes
4. Verify: 2 minutes

**Total: ~10 minutes**

---

**Ready? Run:** `supabase db push`
