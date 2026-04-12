// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract AirdropPlatform {
    address public feeRecipient;
    uint256 public constant FEE = 0.01 ether;

    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "ZERO_ADDR");
        feeRecipient = _feeRecipient;
    }

    function setFeeRecipient(address _newRecipient) external {
        require(msg.sender == feeRecipient, "NOT_AUTH");
        require(_newRecipient != address(0), "ZERO_ADDR");

        emit FeeRecipientUpdated(feeRecipient, _newRecipient);
        feeRecipient = _newRecipient;
    }

    function AirdropTokens(
        address _token,
        address[] calldata _addresses,
        uint256[] calldata _amounts,
        uint256 _totalAmount
    ) external payable {
        require(msg.value >= FEE, "FEE");

        assembly {
            if iszero(eq(_addresses.length, _amounts.length)) {
                revert(0, 0)
            }

            mstore(0x00, hex"23b872dd")
            mstore(0x04, caller())
            mstore(0x24, address())
            mstore(0x44, _totalAmount)

            if iszero(call(gas(), _token, 0, 0x00, 0x64, 0, 0)) {
                revert(0, 0)
            }

            mstore(0x00, hex"a9059cbb")

            let addrOffset := _addresses.offset
            let amtOffset := _amounts.offset
            let end := add(addrOffset, shl(5, _addresses.length))

            for { } 1 { } {
                mstore(0x04, calldataload(addrOffset))
                mstore(0x24, calldataload(amtOffset))

                if iszero(call(gas(), _token, 0, 0x00, 0x64, 0, 0)) {
                    revert(0, 0)
                }

                addrOffset := add(addrOffset, 0x20)
                amtOffset := add(amtOffset, 0x20)

                if iszero(lt(addrOffset, end)) { break }
            }
        }

        (bool ok,) = feeRecipient.call{value: FEE}("");
        require(ok, "FEE_SEND_FAIL");

        if (msg.value > FEE) {
            (bool refund,) = msg.sender.call{value: msg.value - FEE}("");
            require(refund, "REFUND_FAIL");
        }
    }

    receive() external payable {}
}