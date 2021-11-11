pragma solidity ^0.8.7;

library Array {
    function removeElement(uint256[] storage _array, uint256 _element) public {
        uint256 lastElement = _array.length - 1;
        for (uint256 i; i<lastElement; i++) {
            if (_array[i] == _element) {
                if (_array[i] == lastElement) {
                    _array.pop();
                }
                else {
                    delete _array[i];
                    _array[i] = _array[lastElement];
                    _array.pop();
                }
            }
        }
    }
}