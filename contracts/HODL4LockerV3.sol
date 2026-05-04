// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title  HODL4 LP Locker
 * @author HODL.DANCE
 * @notice Locks a Uniswap V3 / PancakeSwap V3 liquidity position (ERC-721 NFT)
 *         until a fixed unlock timestamp. The owner can collect swap fees at
 *         any time without touching the underlying liquidity.
 *         The contract is reusable — after withdraw() a new position can be locked
 *         and the unlock time can be extended between locks.
 *
 * ╔══════════════════════════════════════════════════════════╗
 * ║               HODL.DANCE  |  LP LOCKER v3                ║
 * ╚══════════════════════════════════════════════════════════╝
 *
 * @dev HOW IT WORKS:
 *
 *  1. Deploy this contract, passing:
 *       _npm         - Uniswap V3 NonfungiblePositionManager address
 *                      BSC mainnet: 0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613
 *       _unlockTime  - Unix timestamp after which the NFT can be withdrawn
 *                      Use https://www.unixtimestamp.com to convert a date.
 *                      Must be at least 1 day in the future.
 *
 *  2. Send your LP NFT to this contract via:
 *       npm.safeTransferFrom(yourWallet, lockerAddress, tokenId)
 *     The contract stores the tokenId and marks itself as initialised.
 *
 *  3. Call collectFees() whenever you want to claim accrued swap-fee revenue.
 *     This DOES NOT move liquidity — it only harvests token0 + token1 fees
 *     that accumulated in the position.
 *
 *  4. After unlockTime has passed, call withdraw() to recover the NFT.
 *
 *  5. Optionally call setUnlockTime() BEFORE sending the next NFT to extend
 *     the lock period. Can only be called when no NFT is locked and only
 *     to a time further in the future than the current unlockTime.
 *
 * ---------------------------------------------------------
 *  SECURITY PROPERTIES:
 *  [v2] npm address validated in constructor (not zero address)
 *  [v2] withdraw() follows CEI pattern — state cleared before transfer
 *  [v2] tokenId zeroed on withdraw to prevent stale getLockInfo() reads
 *  [v2] Events emitted for all state-changing actions (GoPlus / DexScreener)
 *  [v2] IERC721Receiver interface explicitly implemented
 *  [v2] receive() reverts to prevent accidental BNB deposits
 *  [v3] unlockTime is mutable but ONLY extendable (never shortenable)
 *  [v3] setUnlockTime() blocked while NFT is locked (initialized = true)
 *  [v3] setUnlockTime() requires new time > current unlockTime AND >= 1 day from now
 *  [v3] Contract is reusable across multiple lock cycles
 *
 *  owner is immutable — set once in constructor, never changeable
 *  npm is immutable — position manager fixed at deployment
 *  Only one NFT can be locked at a time (initialized guard)
 *  Only the NonfungiblePositionManager may deliver the NFT
 *  collectFees() is owner-only and does not alter liquidity
 *  withdraw() is owner-only and enforces the time-lock on-chain
 *  unlockTime can only be EXTENDED, never shortened — even by the owner
 * ---------------------------------------------------------
 *
 * @custom:platform  https://hodl.dance
 * @custom:network   BNB Chain (BSC) - chainId 56
 * @custom:npm-bsc   0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613
 * @custom:version   3.0.0
 */

interface INonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params)
        external returns (uint256 amount0, uint256 amount1);
    function safeTransferFrom(address from, address to, uint256 id) external;
    function ownerOf(uint256 id) external view returns (address);
}

contract HODL4Locker is IERC721Receiver {

    // -- Events -------------------------------------------

    event NFTLocked(uint256 indexed tokenId, uint256 unlockTime);
    event FeesCollected(uint256 amount0, uint256 amount1);
    event NFTWithdrawn(uint256 indexed tokenId, address indexed to);
    event UnlockTimeExtended(uint256 oldUnlockTime, uint256 newUnlockTime);

    // -- State --------------------------------------------

    address public immutable owner;
    INonfungiblePositionManager public immutable npm;
    uint256 public unlockTime;   // mutable — only extendable via setUnlockTime()
    uint256 public tokenId;
    bool    public initialized;

    // -- Modifier -----------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "HODL4Locker: caller is not owner");
        _;
    }

    // -- Constructor --------------------------------------

    constructor(address _npm, uint256 _unlockTime) {
        require(_npm != address(0),                         "HODL4Locker: npm is zero address");
        require(_unlockTime >= block.timestamp + 1 days,    "HODL4Locker: unlock must be >= 1 day from now");

        owner      = msg.sender;
        npm        = INonfungiblePositionManager(_npm);
        unlockTime = _unlockTime;
    }

    // -- ERC-721 receiver ---------------------------------

    function onERC721Received(
        address, address, uint256 _tokenId, bytes calldata
    ) external override returns (bytes4) {
        require(!initialized,               "HODL4Locker: already locked");
        require(msg.sender == address(npm), "HODL4Locker: sender is not NPM");

        tokenId     = _tokenId;
        initialized = true;

        emit NFTLocked(_tokenId, unlockTime);
        return IERC721Receiver.onERC721Received.selector;
    }

    // -- Fee collection -----------------------------------

    function collectFees() external onlyOwner returns (uint256 amount0, uint256 amount1) {
        require(initialized, "HODL4Locker: no position locked");

        (amount0, amount1) = npm.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId:    tokenId,
                recipient:  owner,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        emit FeesCollected(amount0, amount1);
    }

    // -- Withdraw -----------------------------------------

    function withdraw() external onlyOwner {
        require(block.timestamp >= unlockTime, "HODL4Locker: still locked");

        uint256 _tokenId = tokenId;
        initialized      = false;
        tokenId          = 0;

        emit NFTWithdrawn(_tokenId, owner);
        npm.safeTransferFrom(address(this), owner, _tokenId);
    }

    // -- Lock time extension ------------------------------

    /// @notice Extends the unlock time for the next lock cycle.
    ///         Can ONLY be called when no NFT is currently locked.
    ///         New time must be strictly greater than current unlockTime
    ///         and at least 1 day from now.
    function setUnlockTime(uint256 _newUnlockTime) external onlyOwner {
        require(!initialized,                                "HODL4Locker: position is locked");
        require(_newUnlockTime > unlockTime,                 "HODL4Locker: must be later than current unlock");
        require(_newUnlockTime >= block.timestamp + 1 days,  "HODL4Locker: unlock must be >= 1 day from now");

        uint256 _old = unlockTime;
        unlockTime   = _newUnlockTime;

        emit UnlockTimeExtended(_old, _newUnlockTime);
    }

    // -- View helpers -------------------------------------

    function getLockInfo() external view returns (
        uint256 _tokenId, uint256 _unlockTime, bool _locked
    ) {
        return (tokenId, unlockTime, initialized);
    }

    // -- Safety -------------------------------------------

    receive() external payable {
        revert("HODL4Locker: BNB not accepted");
    }
}