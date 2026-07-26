// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title AirdropPlatform
 * @notice Batch airdrop tool for ERC20 tokens with a fixed fee.
 * @dev Tokens are pulled to the contract and then distributed.
 *      Includes protection against draining stranded tokens.
 */
contract AirdropPlatform {
    // Address that receives the airdrop fee
    address public feeRecipient;

    // Fixed fee per airdrop transaction (0.01 BNB / ETH)
    uint256 public constant FEE = 0.01 ether;

    // Emitted when the fee recipient is updated
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    /**
     * @notice Sets the initial fee recipient
     * @param _feeRecipient Address that will receive fees
     */
    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "ZERO_ADDR");
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Updates the fee recipient
     * @dev Only the current feeRecipient can call this function
     * @param _newRecipient New address to receive fees
     */
    function setFeeRecipient(address _newRecipient) external {
        require(msg.sender == feeRecipient, "NOT_AUTH");
        require(_newRecipient != address(0), "ZERO_ADDR");

        emit FeeRecipientUpdated(feeRecipient, _newRecipient);
        feeRecipient = _newRecipient;
    }

    /**
     * @notice Distributes tokens to multiple recipients in a single transaction
     * @param _token        ERC20 token address
     * @param _addresses    Array of recipient addresses
     * @param _amounts      Array of amounts to send to each recipient
     * @param _totalAmount  Total amount that must equal the sum of _amounts
     */
    function AirdropTokens(
        address _token,
        address[] calldata _addresses,
        uint256[] calldata _amounts,
        uint256 _totalAmount
    ) external payable {
        // Must pay at least the fixed fee
        require(msg.value >= FEE, "FEE");
        require(_token != address(0), "ZERO_TOKEN");
        require(_addresses.length > 0, "EMPTY");
        require(_addresses.length == _amounts.length, "LENGTH_MISMATCH");

        // === Security check ===
        // Prevents leaving surplus tokens in the contract that could later be drained
        uint256 sum;
        for (uint256 i; i < _amounts.length; ++i) {
            sum += _amounts[i];
        }
        require(sum == _totalAmount, "AMOUNT_MISMATCH");

        // Pull tokens from sender and distribute them
        assembly {
            // transferFrom(msg.sender, address(this), _totalAmount)
            mstore(0x00, hex"23b872dd")         // transferFrom selector
            mstore(0x04, caller())              // from = msg.sender
            mstore(0x24, address())             // to = this contract
            mstore(0x44, _totalAmount)          // amount
            if iszero(call(gas(), _token, 0, 0x00, 0x64, 0, 0)) {
                revert(0, 0)
            }

            // Now transfer to each recipient
            mstore(0x00, hex"a9059cbb")         // transfer selector
            let addrOffset := _addresses.offset
            let amtOffset := _amounts.offset
            let end := add(addrOffset, shl(5, _addresses.length))

            for { } 1 { } {
                mstore(0x04, calldataload(addrOffset))  // recipient
                mstore(0x24, calldataload(amtOffset))   // amount
                if iszero(call(gas(), _token, 0, 0x00, 0x64, 0, 0)) {
                    revert(0, 0)
                }

                addrOffset := add(addrOffset, 0x20)
                amtOffset := add(amtOffset, 0x20)

                if iszero(lt(addrOffset, end)) { break }
            }
        }

        // Send the fee to feeRecipient
        (bool ok,) = feeRecipient.call{value: FEE}("");
        require(ok, "FEE_SEND_FAIL");

        // Refund any excess BNB/ETH sent by the caller
        if (msg.value > FEE) {
            (bool refund,) = msg.sender.call{value: msg.value - FEE}("");
            require(refund, "REFUND_FAIL");
        }
    }

    /**
     * @notice Allows the fee recipient to rescue any tokens accidentally sent to this contract
     * @param _token  Token address to rescue
     * @param _to     Address that will receive the rescued tokens
     * @param _amount Amount to rescue
     */
    function rescueTokens(address _token, address _to, uint256 _amount) external {
        require(msg.sender == feeRecipient, "NOT_AUTH");
        require(_to != address(0), "ZERO_ADDR");
        require(_token != address(0), "ZERO_TOKEN");

        (bool success, bytes memory data) = _token.call(
            abi.encodeWithSelector(0xa9059cbb, _to, _amount) // transfer(to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "RESCUE_FAIL");
    }

    // Allows the contract to receive native currency
    receive() external payable {}
}
