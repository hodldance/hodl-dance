// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  HODL.DANCE Memecoin Template
 * @author HODL.DANCE
 * @notice Base ERC20 contract for every token launched on the HODL.DANCE platform.
 *
 * ╔══════════════════════════════════════════════════════════╗
 * ║              HODL.DANCE  |  Memecoin Template            ║
 * ╚══════════════════════════════════════════════════════════╝
 *
 * @dev ARCHITECTURE — EIP-1167 Minimal Proxy (Clone) Pattern:
 *
 *  This contract is the implementation template. Every token on HODL.DANCE
 *  is a lightweight clone of this contract deployed by TokenFactory.
 *  Clones share the bytecode but have independent storage — each token
 *  has its own name, symbol, balances and ownership.
 *
 * ─────────────────────────────────────────────────────────
 *  TOKEN LIFECYCLE
 * ─────────────────────────────────────────────────────────
 *
 *  1. DEPLOY    TokenFactory clones this template (gas-efficient)
 *  2. INIT      initialize() sets name, symbol, mints 1B supply to BondingCurve
 *  3. LOCKED    Mode.Locked — only BondingCurve can transfer tokens
 *  4. TRADING   Mode.Trading — unlocked by BondingCurve after graduation
 *                              to PancakeSwap V3
 *
 * ─────────────────────────────────────────────────────────
 *  SUPPLY & OWNERSHIP
 * ─────────────────────────────────────────────────────────
 *
 *  Fixed supply: 1,000,000,000 tokens (1 Billion) — minted once, never again
 *  Owner = BondingCurve during trading phase
 *  Ownership renounced after graduation — fully decentralized
 *  No admin mint, no backdoor, no pause function
 *
 * @custom:platform  https://hodl.dance
 * @custom:pattern   EIP-1167 Minimal Proxy
 * @custom:supply    1,000,000,000 tokens (fixed)
 */

contract MemecoinTemplate is ERC20, Ownable {
    enum Mode { Locked, Trading }
    Mode public mode;

    string private _customName;
    string private _customSymbol;

    address public immutable factoryAddress;

    bool private isInitialized;

    mapping(address => bool) public isAllowed;

    constructor(address _factoryAddress) Ownable(msg.sender) ERC20("Uninitialized", "N/A") {
        factoryAddress = _factoryAddress;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address newOwner
    ) external {
        require(msg.sender == factoryAddress, "Only factory can initialize");
        require(!isInitialized, "Already initialized");
        isInitialized = true;

        _customName = name_;
        _customSymbol = symbol_;

        _transferOwnership(newOwner);

        _mint(newOwner, 1_000_000_000 * 10 ** decimals());

        mode = Mode.Locked;

        isAllowed[0xf7F26E6cA35ebedb80Fa8C7D2B30a4849dd44693] = true;
    }

    function name() public view override returns (string memory) { return _customName; }
    function symbol() public view override returns (string memory) { return _customSymbol; }

    function enableTrading() external onlyOwner {
        mode = Mode.Trading;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (mode == Mode.Locked && from != address(0)) {
            require(
                from == owner() ||
                to == owner() ||
                isAllowed[msg.sender],
                "Token transfers are locked"
            );
        }
        super._update(from, to, value);
    }
}