// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract ContextMixin {
    function msgSender()
        internal
        view
        returns (address payable sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }
}



contract HikuruNFT is ERC1155, AccessControl, ERC1155Pausable, ERC1155Supply, ContextMixin {
    using Strings for uint256;
    string public name;
    string public symbol;
    uint256 public maxSupply;
    address private _recipient;
    address public hikuruPiggyBank;


    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(address initialOwner, string memory _name, string memory _symbol, uint256 _max_supply, address recipient, string memory _url)
        ERC1155(_url)
    {
        name = _name;
        symbol = _symbol;
        maxSupply = _max_supply;
        _recipient = recipient;

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner); // set factory as admin
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); // creator as admin
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }


    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyRole(DEFAULT_ADMIN_ROLE) 
        whenNotPaused
    {
        require(totalSupply(id) + amount <= maxSupply || maxSupply == 0, "Max Supply Exceeded");
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(DEFAULT_ADMIN_ROLE) 
        whenNotPaused
    {
        _mintBatch(to, ids, amounts, data);
    }


    // The following functions are overrides required by Solidity.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    /** @dev EIP2981 royalties implementation. */

    // Maintain flexibility to modify royalties recipient (could also add basis points).
    // function _setRoyalties(address newRecipient) internal {
    //     require(newRecipient != address(0), "Royalties: new recipient is the zero address");
    //     _recipient = newRecipient;
    // }

    // function setRoyalties(address newRecipient) external onlyRole(DEFAULT_ADMIN_ROLE)  {
    //     _setRoyalties(newRecipient);
    // }

    // EIP2981 standard royalties return.
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view
        returns (address receiver, uint256 royaltyAmount)
    {
        return (_recipient, (_salePrice * 700) / 10000);
    }

    function _msgSender() internal override view returns (address) {
        return ContextMixin.msgSender();
    }

}
