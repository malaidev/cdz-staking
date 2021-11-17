pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Harvest is Ownable {
    using Address for address;

    struct Data {
        uint256[] tokens;
        uint256 stakingPeriod;
        uint256 amountOfStakers;
        address user;
        address collection;
        bool isStakable;
    }

    uint256 private fee;
    address payable devAddress;

    function setData(
        uint256[] memory _tokens,
        uint256 _stakingPeriod,
        uint256 _amountOfStakers,
        address _user,
        address _collection,
        bool _isStakable
    ) public onlyOwner {
        Data memory data = Data(
            _tokens,
            _stakingPeriod,
            _amountOfStakers,
            _user,
            _collection,
            _isStakable
        );
    }

    function harvest() public payable {
        Data memory data;
        require(
            msg.value > fee, "Harvest.harvest: Cover fee"
        );
        require(
            data.user == msg.sender,
            "Harvest.harvest: Tempered user address"
        );
        require(
            data.isStakable == true,
            "Harvest.harvest: Staking isn't available in given pool"
        );
        require(
            data.amountOfStakers != 0,
            "Harvest.harvest: You can't harvest, if pool is empty"
        );

        uint256 reward = 0;
        for (uint256 x; x < data.tokens.length; ++x) {
            reward += _getRewards(
                data.collection,
                data.tokens[x],
                data.stakingPeriod,
                data.amountOfStakers
            );
        }

        sendFee(devAddress, msg.value);
        //llth.mint(msg.sender, reward);
    }

    function _getRewards(
        address _collection,
        uint256 _id,
        uint256 _stakingPeriod,
        uint256 _amountOfStakers
    ) internal returns (uint256) {}

    function sendFee(address payable _to, uint256 _value) public payable {
        (bool sent, bytes memory data) = _to.call{ value: _value }("");
        require(sent, "Harvest.sendFee: Failed to send fee");
    }

    function setFee(uint256 _value) public onlyOwner {
        require(fee != _value, "Harvest.setFee: Value already set");
        fee = _value;
    }

    function setDev(address payable _newDev) public onlyOwner {
        require(devAddress != _newDev, "Harvest.setDev: Address already set");
        devAddress = _newDev;
    }

    receive() external payable {}
}
