# Quick Start - Member dapat Pot ID & Setor

## 🎯 Member Experience (Optimal Flow)

### ✅ Skenario Ideal: Member dapat link dari admin

```
Admin share: https://yourdomain.com/pot/0xd01eba3a732dabb97b6e3bc64f59a37810d1283d00d2639472188409d4926a9e

Member buka link ↓
  ├─ Auto-load pot info
  ├─ Cek: apakah member?
  ├─ Cek: bisa deposit?
  ├─ Tampilkan form setor
  ├─ Load coin list otomatis
  ├─ Member pilih coin
  └─ Click "Setor Dana"
    ↓
  Approve di wallet ↓
    ↓
  ✅ Dana masuk pot!
```

---

## 📱 UI Flow: Member Setor via Link

### Screen 1: Halaman Pot (Auto-loaded)

```
┌─────────────────────────────┐
│ 🍲 Arisan Keluarga          │
│ Arisan komunitas di Sui     │
│                             │
│ Status: 🟡 Sedang Deposit  │
│                             │
│ ┌───────────────────────┐   │
│ │ Periode: 1 / 3        │   │
│ │ Total Member: 3       │   │
│ │ Setor per Member: 1   │   │
│ │   SUI                 │   │
│ │ Total Dana: 1 SUI     │   │
│ │ Yang setor: 0 / 3     │   │
│ └───────────────────────┘   │
│                             │
│ [Connect Wallet]            │
└─────────────────────────────┘
```

### Screen 2: Pilih Coin

```
┌─────────────────────────────┐
│ 💰 Setor Dana Anda          │
│                             │
│ Pilih SUI Coin untuk Disetor│
│                             │
│ ┌─ ○ 0x123...45 ────────┐ │
│ │   1.5 SUI ✅            │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─ ○ 0x456...78 ────────┐ │
│ │   0.5 SUI               │ │
│ │   (Kurang 0.5 SUI)      │ │
│ └─────────────────────────┘ │
│                             │
│ Akan setor: 1 SUI           │
│                             │
│ [✅ Setor Dana]             │
└─────────────────────────────┘
```

### Screen 3: Success

```
┌─────────────────────────────┐
│ ✅ Deposit Berhasil!        │
│                             │
│ Terima kasih! Dana Anda     │
│ sudah masuk pot.            │
│                             │
│ Menunggu member lain untuk  │
│ setor sebelum undian        │
│ dilakukan                   │
│                             │
│ Yang sudah setor: 1 / 3     │
│                             │
│ Total Dana: 1 SUI / 3 SUI   │
│ [Progress bar]              │
│                             │
│ Pemenang sebelumnya:        │
│ (Belum ada)                 │
└─────────────────────────────┘
```

---

## 🔐 Validasi Member (Backend Logic)

```typescript
// File: src/components/MemberView.tsx

const isMember = pot?.members?.includes(account?.address);
const hasDeposited = pot?.deposits_this_period?.includes(account?.address);
const canDeposit = pot?.status === 0 && isMember && !hasDeposited;

// Status checking
if (!isMember) {
  // Show: "Anda bukan member"
} else if (hasDeposited && pot.status === 0) {
  // Show: "✅ Anda sudah setor"
} else if (pot.status === 1) {
  // Show: "🎲 Menunggu undian"
} else if (pot.status === 2) {
  // Show: "✅ Arisan selesai"
} else if (canDeposit) {
  // Show deposit form
}
```

---

## 🎁 Coin Selection Auto-Load

```typescript
// File: src/hooks/usePotInfo.ts + useEffect

useEffect(() => {
  if (!account?.address) return;

  // Load coins setelah user connect wallet
  (async () => {
    const coins = await getUserCoins(account.address);
    
    // Filter: hanya yang cukup untuk setor
    const enoughCoins = coins.filter(c => 
      parseInt(c.balance) >= parseInt(pot.depositAmount)
    );

    setCoins(coins); // Tampilkan semua
    
    // Auto-select coin yang cukup
    if (enoughCoins.length > 0) {
      setSelectedCoinId(enoughCoins[0].coinId);
    }
  })();
}, [account?.address]);
```

---

## 🚀 Deploy Link

Admin dapat Pot ID setelah deploy:

```
Package ID:
0xd01eba3a732dabb97b6e3bc64f59a37810d1283d00d2639472188409d4926a9e

Pot ID (setelah create):
0xabc123...

Share link:
https://yourdomain.com/pot/0xabc123...

QR Code:
[Generate QR dari link di atas]
```

---

## ⚡ Member Experience Benefits

```
❌ OLD (Manual)
├─ Copy Pot ID dari admin
├─ Pergi ke dashboard
├─ Paste Pot ID
├─ Tunggu load
├─ Copy Coin ID dari wallet
├─ Paste Coin ID
├─ Click Setor
├─ Approve
└─ ✅ Setor berhasil

✅ NEW (Link-based)
├─ Click link dari admin
├─ ✅ Halaman auto-load
├─ ✅ Coin auto-load
├─ Pilih coin (1 klik)
├─ Click Setor
├─ Approve
└─ ✅ Setor berhasil

Benefit: 5 step lebih sedikit + lebih user-friendly!
```

---

## 📊 Real-Time Updates

Saat member setor:

```
Frontend:
├─ Listen untuk event DepositMade
├─ Update pot info
├─ Update deposit counter
├─ Update balance
└─ Show confetti animation ✨

If semua sudah setor:
├─ Auto-detect (length === members.length)
├─ Update status → 🟢 Ready to Draw
├─ Show notification ke admin
└─ Admin bisa trigger draw
```

---

## 💡 Tips untuk Developer

1. **Routing Setup**
   ```typescript
   npm install react-router-dom
   // src/App.tsx
   <Route path="/pot/:potId" element={<MemberView />} />
   ```

2. **Query Persistence**
   ```typescript
   // Refresh page, link parameter tetap
   // Data state auto-load dari blockchain
   ```

3. **Mobile Responsive**
   ```tsx
   // Gunakan Tailwind responsive classes
   className="grid md:grid-cols-2 gap-4"
   ```

4. **Loading States**
   ```typescript
   if (isLoading) return <Spinner />
   if (error) return <ErrorMessage />
   if (!data) return <EmptyState />
   ```

---

## 🎯 Summary

**Member dapat Pot ID dari admin:**

1. ✅ Buka link di browser
2. ✅ System auto-load semua info
3. ✅ System auto-load wallet coins
4. ✅ Member pilih coin & setor
5. ✅ Selesai dalam 2 menit

**No copy-paste needed. Pure UX magic! 🚀**
