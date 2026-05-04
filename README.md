# HODL.DANCE — Memecoin Launchpad on BSC

> Launch, Trade, Earn and Dance with Memecoins 🕺

## Website
https://hodl.dance

---

## What is HODL.DANCE?

HODL.DANCE is a decentralized memecoin launchpad on BNB Smart Chain, where token creators earn continuously — not just at launch, but throughout the entire life of their project.

Every token starts on a **Bonding Curve** — an automatic price discovery mechanism where the price rises with every purchase. Once a token reaches the capitalization threshold (19 BNB), liquidity moves to **PancakeSwap V3** and gets **permanently locked** in the Locker smart contract. From that point, every V3 transaction generates fees that the creator can regularly claim.

Unlike other platforms that burn liquidity after migration — **HODL.DANCE locks it**. Traders get a guarantee of liquidity. Creators get a guarantee of revenue.

The platform also distributes a portion of transaction fees to active ecosystem participants through the **Rewards Program**.

---

## How It Works

1. Creator launches token via **TokenFactory**
2. Token trades on **Bonding Curve** (CPMM — constant product market maker)
3. At **19 BNB threshold** → automatic migration to PancakeSwap V3
4. LP permanently locked in **Locker** smart contract
5. Creator claims V3 fees anytime through the platform

---

## Deployed Contracts (BSC Mainnet)

| Contract | Address | Source |
|---|---|---|
| HODL4 Token | `0x197fb6855E0D6a237a7AB6228e3a0B8168fe5dEc` | Public |
| HODL4 Locker | `0xc6c74eb9ec01799e4D5e58574769d54391B05F0A` | Public |
| DANCEMAN | `0xdd0a56050c66c514bb6c3ef7f940cfe25f549020` | Public |
| Airdrop HODL4 | `0x63F8b68b7D96E0Cf31fC22d21D8cE6F4d7C56D1c` | Public |
| Token Factory | `0x99A1F02f56E8356e6E90A880DBb1be6EC7485737` | Public after audit |
| Memecoin Template | `0x28fECa617A7b94297795d0FBCCda88D8cD8D3382` | Public |
| Bonding Curve Template | `0xea508aD6B550E94aC45831F265B2bD5346d06700` | Public after audit |
| Ad Payment Gateway | `0x5876a2cE3b44d8785ED2A96CCD60C76180A3ff83` | Public |
| Profile Activator | `0x44484af893a62dcd78a0c6b50360b85d8bde4f5b` | Public |
| Verification Payer | `0xF6D96668B5966Bb943Ad66a95acc677282CBe726` | Public |
| Locker | `0x7aED5c149E32Ff72FfA1eA334DBef652e40a19E7` | Public after audit |
| Airdrop Tool | `0xf7F26E6cA35ebedb80Fa8C7D2B30a4849dd44693` | Public |

> ⚠️ **Token Factory**, **Bonding Curve Template** and **Locker** source code will be made public following a third-party security audit.

---

## Repository Structure

```
hodl-dance/
├── README.md
├── contracts/        # Smart contracts (public ones)
├── audits/           # Audit reports (coming soon)
├── backend/          # Backend source (coming soon)
└── frontend/         # Frontend source (coming soon)
```

---

## Key Features

- 🚀 **1-click token launch** — no coding required
- 📈 **Bonding Curve pricing** — fair price discovery, no presale
- 🔒 **Permanent LP lock** — liquidity locked forever after graduation
- 💰 **Creator fee claiming** — earn from PancakeSwap V3 fees continuously
- 🎁 **Rewards Program** — platform fees distributed to active participants
- 🤖 **Buy Bot** — Telegram buy notifications for every token
- ✅ **Verification system** — on-chain project verification
- 📢 **Ads system** — on-chain advertising for token promotion

---

## Security

- No presale, no team token allocation
- Leftover tokens burned on bonding curve graduation
- LP permanently locked — cannot be withdrawn
- 1% transparent platform fee per transaction
- Core contracts pending third-party audit

---

## License

MIT
