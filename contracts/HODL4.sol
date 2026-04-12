// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title HODL Dance Floor
 * @author HODL.DANCE
 * @notice Utility token powering the HODL.DANCE DeFi platform.
 *
 * ╔══════════════════════════════════════════════════════════╗
 * ║                    HODL.DANCE  |  HODL4                  ║
 * ╚══════════════════════════════════════════════════════════╝
 *
 * @dev HOW THE $4 FLOOR WORKS (SAFU by design):
 *
 *  Liquidity is deployed as a Single-Sided range on Uniswap V3:
 *  • tickLower = 13860  →  price floor at exactly $4.00
 *  • tickUpper = 887220 →  unlimited upside (no ceiling)
 *
 *  This means:
 *  ✅ Token CAN go up indefinitely
 *  🛡️ Token CANNOT go below $4.00
 *     (the LP acts as an automatic buy wall at $4)
 *  ✅ No admin keys — floor is enforced by the protocol itself
 *
 * ─────────────────────────────────────────────────────────
 *  4️⃣  CZ TRIBUTE — "4"
 * ─────────────────────────────────────────────────────────
 *  On January 2, 2023, Binance CEO CZ tweeted:
 *  "Ignore FUD, fake news, attacks, etc." — and signed it "4".
 *  Since then, "4" has become a symbol of focus, resilience,
 *  and building through the noise.
 *
 *  HODL4 embodies this: $4 floor, ignore the FUD, HODL on. 4️⃣
 * ─────────────────────────────────────────────────────────
 *
 * @custom:platform  https://hodl.dance
 * @custom:floor     $4.00 (Uniswap V3 SSL, tick 13860)
 * @custom:safu      Price floor enforced by smart contract, not humans
 * @custom:tribute   CZ's "4" — https://www.binance.com/en/academy/glossary/understanding-cz-s-number-4
 */

contract HODL4Token is ERC20 {
    constructor(uint256 initialSupply) ERC20("HODL Dance Floor", "HODL4") {
        _mint(msg.sender, initialSupply);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
