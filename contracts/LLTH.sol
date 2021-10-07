pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LLTH is ERC20, Ownable {
    using SafeMath for uint256;
    uint256 public LlthTxnFee = 5;
    address public devWallet = 0xb0bbEA2d69a20a332Ff90486761B908482030636;

    mapping(address => bool) internal _onlyApproved;
    mapping(address => bool) internal _isExcluded;

    modifier onlyApproved() {
        require(_onlyApproved[msg.sender] == true);
        _;
    }

    constructor() public ERC20("Lilith", "LLTH") {
        _isExcluded[owner()] = true;
        _mint(owner(), 1000000 * (10**18));
    }

    function mint(address to, uint256 amount) public onlyApproved {
        _mint(to, amount);
    }

    function manageApproves(address _address, bool _value) public onlyOwner {
        _onlyApproved[_address] = _value;
    }

    function withdrawLLTH() public onlyOwner {
        super._transfer(address(this), devWallet, balanceOf(address(this)));
    }

    function changeDevAddress(address _newDevAddress) public onlyOwner {
        require(_newDevAddress != devWallet, "VALUE ALREADY SET");
        devWallet = _newDevAddress;
    }

    function changeFee(uint256 _value) public onlyOwner {
        require(_value != LlthTxnFee, "VALUE ALREADY SET");
        LlthTxnFee = _value;
    }

    function excludeFromFees(address _address, bool _excluded)
        public
        onlyOwner
    {
        require(_isExcluded[_address] != _excluded, "CANT EXCLUDE/INCLUDE");
        _isExcluded[_address] = _excluded;
    }

    function batchExcludeFromFees(address[] calldata _addresses, bool _excluded)
        public
        onlyOwner
    {
        for (uint256 i; i < _addresses.length; ++i) {
            require(
                _isExcluded[_addresses[i]] != _excluded,
                "CANT EXCLUDE/INCLUDE"
            );
            _isExcluded[_addresses[i]] = _excluded;
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (_isExcluded[from] || _isExcluded[to]) {
            super._transfer(from, to, amount);
        }

        uint256 fees = amount.mul(LlthTxnFee).div(100);
        amount = amount.sub(fees);
        super._transfer(from, address(this), fees);
        super._transfer(from, to, amount);
    }
}
