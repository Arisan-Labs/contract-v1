# Sui Group Pot / Arisan

Sistem arisan terdesentralisasi di blockchain Sui - transparansi penuh, randomness yang fair, tanpa perantara.

## ✨ Fitur

- 🎲 **Fair Drawing** - Menggunakan native randomness Sui
- 👥 **Multi-Period** - Support N members = N periods
- 💰 **Immutable** - Semua transaksi tercatat on-chain
- 🔒 **Secure** - Capability-based access control
- ⚡ **Gas Efficient** - Sui gas model yang murah

## 📦 Deployment

**Network:** Sui Testnet  
**Package ID:** `0x1469fc48582a1b211da6a4ef007004956315013dcd285edb51dc3f15a5f55d36`  
**Explorer:** https://testnet.suivision.com

## 🏗️ Struktur

```
sources/arisan.move      # Smart contract (319 lines)
tests/arisan_tests.move  # Unit tests (9 test cases)
Move.toml               # Package config
```

## 🎯 Core Functions

| Function | Deskripsi |
|----------|-----------|
| `create_pot()` | Admin buat pot dengan members |
| `deposit()` | Member setor SUI ke pot |
| `draw_winner()` | Admin trigger drawing untuk pilih pemenang |
| View functions | Query status, balance, winners |

## 📋 Quick Start

### Setup Wallet
```bash
sui keytool import <private-key> ed25519
sui client switch --env testnet
```

### Create Pot
```bash
sudo client call --package 0x1469fc48582a1b211da6a4ef007004956315013dcd285edb51dc3f15a5f55d36 \
  --module arisan \
  --function create_pot \
  --args "Arisan Keluarga" 1000000000 \
    '[0xaddr1,0xaddr2,0xaddr3]'
```

### Deposit
```bash
sudo client call --package 0x1469fc48582a1b211da6a4ef007004956315013dcd285edb51dc3f15a5f55d36 \
  --module arisan \
  --function deposit \
  --args <pot-id> <coin-id>
```

### Draw Winner
```bash
sudo client call --package 0x1469fc48582a1b211da6a4ef007004956315013dcd285edb51dc3f15a5f55d36 \
  --module arisan \
  --function draw_winner \
  --args <pot-id> <admin-cap-id>
```

---

## Generated: 31 Januari 2026
