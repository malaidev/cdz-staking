//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

library Array {
    /**
    *   @notice remove given elements from array
    *   @dev usable only if _array contains unique elements only
     */
    function removeElement(uint256[] storage _array, uint256 _element) public {
        for (uint256 i; i<_array.length; i++) {
            if (_array[i] == _element) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                break;
            }
        }
    }
}