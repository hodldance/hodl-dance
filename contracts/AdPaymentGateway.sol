// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title  HODL.DANCE Ad Payment Gateway
 * @author HODL.DANCE
 * @notice On-chain payment contract for purchasing promoted token slots on HODL.DANCE.
 *
 * ╔══════════════════════════════════════════════════════════╗
 * ║           HODL.DANCE  |  Ad Payment Gateway              ║
 * ╚══════════════════════════════════════════════════════════╝
 *
 * @dev ARCHITECTURE — Stateless Payment Pass-Through:
 *
 *  This contract does NOT hold funds. Every payment is forwarded
 *  immediately to feeCollector in the same transaction.
 *  The contract serves purely as an on-chain record of ad purchases,
 *  enabling trustless verification of promoted slots via event logs.
 *
 * ─────────────────────────────────────────────────────────
 *  AD PURCHASE FLOW
 * ─────────────────────────────────────────────────────────
 *
 *  1. ADVERTISER   Calls purchaseAd(token, duration) with BNB
 *  2. VALIDATION   Duration 1–24h, token address, sufficient fee
 *  3. PAYMENT      requiredFee forwarded to feeCollector instantly
 *  4. REFUND       Any excess BNB returned to advertiser
 *  5. EVENT        AdPurchased emitted — backend picks up and activates slot
 *
 * ─────────────────────────────────────────────────────────
 *  PRICING
 * ─────────────────────────────────────────────────────────
 *
 *  Hourly rate: pricePerHour (default 0.05 BNB/h)
 *  Daily flat:  price24h    (default 1.00 BNB — discount vs 24 * hourly)
 *  Prices adjustable by owner via setPrices()
 *  price24h always validated against hourly rate (no inconsistency)
 *
 * ─────────────────────────────────────────────────────────
 *  SECURITY
 * ─────────────────────────────────────────────────────────
 *
 *  ReentrancyGuard on purchaseAd — payment before refund (CEI)
 *  Ownable — full ownership transfer support (multisig ready)
 *  No funds held — minimizes attack surface
 *  Emergency withdraw to feeCollector if BNB gets stuck
 *
 * @custom:platform  https://hodl.dance
 * @custom:pattern   Stateless pass-through payment gateway
 */

contract AdPaymentGateway is Ownable, ReentrancyGuard {
    address public feeCollector;

    uint256 public pricePerHour = 0.05 ether;
    uint256 public price24h     = 1 ether;

    event AdPurchased(
        address indexed advertiser,
        address indexed token,
        uint256 durationHours,
        uint256 feePaid,
        uint256 timestamp
    );
    event FeeCollectorUpdated(address indexed newCollector);
    event PriceUpdated(uint256 newPricePerHour, uint256 newPrice24h);

    constructor(address _feeCollector) Ownable(msg.sender) {
        require(_feeCollector != address(0), "Invalid fee collector");
        feeCollector = _feeCollector;
    }

    /// @notice Returns the current fee collector address
    function getFeeCollector() external view returns (address) {
        return feeCollector;
    }

    /**
     * @notice Purchase a promoted ad slot for a token
     * @param token    Address of the token to promote
     * @param duration Slot duration in hours (1–24)
     * @dev Payment forwarded to feeCollector immediately; excess BNB refunded
     */
    function purchaseAd(address token, uint8 duration) external payable nonReentrant {
        require(token != address(0), "Invalid token");
        require(duration >= 1 && duration <= 24, "Duration must be 1-24h");

        uint256 requiredFee = calculateFee(duration);
        require(msg.value >= requiredFee, "Insufficient fee");

        // CEI: payment to collector first, refund second
        (bool success, ) = feeCollector.call{value: requiredFee}("");
        require(success, "Payment failed");

        if (msg.value > requiredFee) {
            (bool ok, ) = msg.sender.call{value: msg.value - requiredFee}("");
            require(ok, "Refund failed");
        }

        emit AdPurchased(msg.sender, token, duration, requiredFee, block.timestamp);
    }

    /**
     * @notice Calculate the fee for a given duration
     * @param duration Hours (1–24); 24h uses flat price24h rate
     */
    function calculateFee(uint8 duration) public view returns (uint256) {
        if (duration == 24) return price24h;
        return pricePerHour * duration;
    }

    /// @notice Update hourly ad price — owner only
    function setPricePerHour(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be > 0");
        pricePerHour = newPrice;
        emit PriceUpdated(newPrice, price24h);
    }

    /// @notice Update 24h flat ad price — owner only
    function setPrice24h(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be > 0");
        price24h = newPrice;
        emit PriceUpdated(pricePerHour, newPrice);
    }

    /// @notice Update both prices atomically — owner only
    function setPrices(uint256 newPricePerHour, uint256 newPrice24h) external onlyOwner {
        require(newPricePerHour > 0 && newPrice24h > 0, "Prices must be > 0");
        require(newPrice24h <= newPricePerHour * 24, "24h price inconsistent");
        pricePerHour = newPricePerHour;
        price24h     = newPrice24h;
        emit PriceUpdated(newPricePerHour, newPrice24h);
    }

    /// @notice Update fee collector address — owner only
    function setFeeCollector(address newCollector) external onlyOwner {
        require(newCollector != address(0), "Invalid address");
        feeCollector = newCollector;
        emit FeeCollectorUpdated(newCollector);
    }

    /// @notice Emergency withdraw stuck BNB to feeCollector — owner only
    function withdraw() external onlyOwner {
        (bool ok, ) = feeCollector.call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }

    receive() external payable {}
}
