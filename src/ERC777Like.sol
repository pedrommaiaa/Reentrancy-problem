// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import "forge-std/console2.sol";

interface IERC1820Registry {
    event InterfaceImplementerSet(address indexed account, bytes32 indexed interfaceHash, address indexed implementer);
    event ManagerChanged(address indexed account, address indexed newManager);

    function setManager(address account, address newManager) external;
    function getManager(address account) external view returns (address);
    function setInterfaceImplementer(address account, bytes32 _interfaceHash, address implementer) external;
    function getInterfaceImplementer(address account, bytes32 _interfaceHash) external view returns (address);
    function interfaceHash(string calldata interfaceName) external pure returns (bytes32);
    function updateERC165Cache(address account, bytes4 interfaceId) external;
    function implementsERC165Interface(address account, bytes4 interfaceId) external view returns (bool);
    function implementsERC165InterfaceNoCache(address account, bytes4 interfaceId) external view returns (bool);
}

interface IERC777Sender {
    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}

interface IERC777Recipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}


contract ERC777Like is ERC20 {

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    IERC1820Registry internal constant ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    constructor() ERC20("ERC777Like", "TST", 18) {}

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _send(msg.sender, recipient, amount, "", "", false);
        return true;
    }

    function transferFrom(
        address holder,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = msg.sender;
        uint256 currentAllowance = allowance[holder][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC777: insufficient allowance");
            require(holder != address(0), "ERC777: approve from the zero address");
            require(spender != address(0), "ERC777: approve to the zero address");

            unchecked { allowance[holder][spender] = currentAllowance - amount; }
            emit Approval(holder, spender, amount);
        }
        
        _send(holder, recipient, amount, "", "", false);
        return true;
    }

    ///////////

    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        address implementer = ERC1820_REGISTRY.getInterfaceImplementer(from, _TOKENS_SENDER_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777Sender(implementer).tokensToSend(operator, from, to, amount, userData, operatorData);
        }
    }

    function _move(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC777: transfer amount exceeds balance");
        unchecked {
            balanceOf[from] = fromBalance - amount;
        }
        balanceOf[to] += amount;

        emit Sent(operator, from, to, amount, userData, operatorData);
        emit Transfer(from, to, amount);
    }

    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) private {
        address implementer = ERC1820_REGISTRY.getInterfaceImplementer(to, _TOKENS_RECIPIENT_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777Recipient(implementer).tokensReceived(operator, from, to, amount, userData, operatorData);
        } else if (requireReceptionAck) {
            require(to.code.length == 0, "ERC777: token recipient contract has no implementer for ERC777TokensRecipient");
        }
    }

    function _send(
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) internal virtual {
        require(from != address(0), "ERC777: transfer from the zero address");
        require(to != address(0), "ERC777: transfer to the zero address");

        _callTokensToSend(msg.sender, from, to, amount, userData, operatorData);
        _move(msg.sender, from, to, amount, userData, operatorData);
        _callTokensReceived(msg.sender, from, to, amount, userData, operatorData, requireReceptionAck);
    }
}