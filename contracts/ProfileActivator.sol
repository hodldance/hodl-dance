// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title  HODL.DANCE Profile Activator
 * @author HODL.DANCE
 * @notice On-chain profile activation — every fee goes directly to charity.
 *
 * ╔══════════════════════════════════════════════════════════╗
 * ║          HODL.DANCE  |  Profile Activator                ║
 * ╚══════════════════════════════════════════════════════════╝
 *
 * @dev ARCHITECTURE — Stateless Charity Pass-Through:
 *
 *  User pays once to activate their HODL.DANCE profile.
 *  100% of the activation fee is forwarded to charityWallet
 *  in the same transaction. Contract holds no funds.
 *
 * ─────────────────────────────────────────────────────────
 *  ACTIVATION FLOW
 * ─────────────────────────────────────────────────────────
 *
 *  1. USER       Calls activateProfile() with BNB >= activationFee
 *  2. STATE      isActivated[user] = true (before any external calls)
 *  3. PAYMENT    activationFee forwarded to charityWallet instantly
 *  4. REFUND     Any excess BNB returned to user
 *  5. EVENT      ProfileActivated emitted — backend unlocks profile
 *
 * ─────────────────────────────────────────────────────────
 *  SECURITY
 * ─────────────────────────────────────────────────────────
 *
 *  ReentrancyGuard — charity payment before refund (CEI)
 *  Ownable — transferOwnership support (multisig ready)
 *  Activation is permanent — owner cannot revoke (trustless)
 *  No funds held — minimizes attack surface
 *  receive() + fallback() reject direct transfers
 *  Emergency withdraw to charityWallet if BNB gets stuck
 *
 * @custom:platform  https://hodl.dance
 * @custom:pattern   Stateless pass-through, permanent single activation
 */

contract ProfileActivator is Ownable, ReentrancyGuard {
    address public charityWallet;
    uint256 public activationFee = 0.01 ether;

    // On-chain activation registry — permanent, immutable per address
    mapping(address => bool) public isActivated;

    event ProfileActivated(address indexed user, uint256 fee);
    event CharityWalletUpdated(address indexed newWallet);
    event ActivationFeeUpdated(uint256 newFee);

    constructor(address _charityWallet) Ownable(msg.sender) {
        require(_charityWallet != address(0), "Invalid charity wallet");
        charityWallet = _charityWallet;
    }

    /**
     * @notice Activate your HODL.DANCE profile by paying the activation fee
     * @dev One-time permanent activation per address. Excess BNB refunded.
     *      CEI: state → charity payment → refund
     */
    function activateProfile() external payable nonReentrant {
        require(msg.value >= activationFee, "Insufficient fee");
        require(!isActivated[msg.sender], "Already activated");

        // Effect: mark activated before any external calls
        isActivated[msg.sender] = true;

        // Interaction 1: charity payment first
        (bool feeSuccess, ) = charityWallet.call{value: activationFee}("");
        require(feeSuccess, "Payment to charity failed");

        // Interaction 2: refund excess
        if (msg.value > activationFee) {
            uint256 refund = msg.value - activationFee;
            (bool refundSuccess, ) = msg.sender.call{value: refund}("");
            require(refundSuccess, "Refund failed");
        }

        emit ProfileActivated(msg.sender, activationFee);
    }

    /// @notice Check if a user has an activated profile
    function isUserActivated(address user) external view returns (bool) {
        return isActivated[user];
    }

    /// @notice Returns current charity wallet address
    function getCharityWallet() external view returns (address) {
        return charityWallet;
    }

    /// @notice Update charity wallet address — owner only
    function setCharityWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid address");
        charityWallet = newWallet;
        emit CharityWalletUpdated(newWallet);
    }

    /// @notice Update activation fee — owner only
    function setActivationFee(uint256 newFee) external onlyOwner {
        require(newFee > 0, "Fee must be > 0");
        activationFee = newFee;
        emit ActivationFeeUpdated(newFee);
    }

    /// @notice Emergency withdraw stuck BNB to charityWallet — owner only
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        (bool success, ) = charityWallet.call{value: balance}("");
        require(success, "Withdraw failed");
    }

    receive() external payable {
        revert("Use activateProfile()");
    }

    fallback() external payable {
        revert("Use activateProfile()");
    }
}
