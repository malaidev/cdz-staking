pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Rewards {
    using SafeMath for uint;

    constructor() public {}

    function calculateReward(
        uint256 _rarity, 
        uint256 _normalizer,
        uint256 _daysStaked, 
        uint256 _multiplier, 
        uint256 _amountOfStakers
    )
        public returns (uint256)
    {

        require(
            _rarity != 0 && 
            _daysStaked !=0 && 
            _multiplier !=0 && 
            _amountOfStakers !=0 &&
            _normalizer !=0, 
            "CANT BE ZERO"
        );

        uint256 baseMultiplier = _multiplier.mul(_daysStaked);
        uint256 baseRarity = _normalizer.mul(_rarity);
        uint256 basemultiplierxRarity = baseMultiplier.mul(baseRarity);
        uint256 finalReward = baseMultiplier.div(_amountOfStakers);

        return finalReward;
    }
}