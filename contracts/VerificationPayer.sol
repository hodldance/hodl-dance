// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title  HODL.DANCE Verification Payer
 * @author HODL.DANCE
 * @notice On-chain payment gateway for token verification requests on HODL.DANCE.
 *
 * ╔══════════════════════════════════════════════════════════╗
 * ║         HODL.DANCE  |  Verification Payer                ║
 * ╚══════════════════════════════════════════════════════════╝
 *
 * @dev ARCHITECTURE — Stateless Payment Pass-Through:
 *
 *  Token creators pay a one-time verification fee to request
 *  manual review and a verified badge on HODL.DANCE.
 *  100% of the fee is forwarded to feeCollector instantly.
 *  Contract holds no funds.
 *
 * ─────────────────────────────────────────────────────────
 *  VERIFICATION FLOW
 * ─────────────────────────────────────────────────────────
 *
 *  1. REQUESTER  Calls requestVerification(token) with BNB
 *  2. VALIDATION token address non-zero, fee sufficient
 *  3. PAYMENT    verificationFee forwarded to feeCollector instantly
 *  4. REFUND     Any excess BNB returned to requester
 *  5. EVENT      VerificationRequested emitted — backend queues review
 *
 * ─────────────────────────────────────────────────────────
 *  SECURITY
 * ─────────────────────────────────────────────────────────
 *
 *  ReentrancyGuard — fee payment before refund (CEI)
 *  Ownable — transferOwnership support (multisig ready)
 *  No funds held — minimizes attack surface
 *  Emergency withdraw to feeCollector if BNB gets stuck
 *
 * @custom:platform  https://hodl.dance
 * @custom:pattern   Stateless pass-through payment gateway
 */

contract VerificationPayer is Ownable, ReentrancyGuard {
    address public feeCollector;
    uint256 public verificationFee = 0.25 ether;

    event VerificationRequested(address indexed token, address indexed requester, uint256 fee);
    event FeeCollectorUpdated(address indexed newCollector);
    event VerificationFeeUpdated(uint256 newFee);

    constructor(address _feeCollector) Ownable(msg.sender) {
        require(_feeCollector != address(0), "Invalid fee collector");
        feeCollector = _feeCollector;
    }

    /// @notice Returns current fee collector address
    function getFeeCollector() external view returns (address) {
        return feeCollector;
    }

    /**
     * @notice Request token verification on HODL.DANCE
     * @param token Address of the token to verify
     * @dev CEI: fee payment to collector first, refund second
     */
    function requestVerification(address token) external payable nonReentrant {
        require(token != address(0), "Invalid token");
        require(msg.value >= verificationFee, "Insufficient fee");

        // Interaction 1: payment to collector first
        (bool success, ) = feeCollector.call{value: verificationFee}("");
        require(success, "Payment failed");

        // Interaction 2: refund excess
        if (msg.value > verificationFee) {
            (bool ok, ) = msg.sender.call{value: msg.value - verificationFee}("");
            require(ok, "Refund failed");
        }

        emit VerificationRequested(token, msg.sender, verificationFee);
    }

    /// @notice Update fee collector address — owner only
    function setFeeCollector(address newCollector) external onlyOwner {
        require(newCollector != address(0), "Invalid address");
        feeCollector = newCollector;
        emit FeeCollectorUpdated(newCollector);
    }

    /// @notice Update verification fee — owner only
    function setFee(uint256 newFee) external onlyOwner {
        require(newFee > 0, "Fee must be > 0");
        verificationFee = newFee;
        emit VerificationFeeUpdated(newFee);
    }

    /// @notice Emergency withdraw stuck BNB to feeCollector — owner only
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        (bool ok, ) = feeCollector.call{value: balance}("");
        require(ok, "Withdraw failed");
    }

    receive() external payable {}
}
