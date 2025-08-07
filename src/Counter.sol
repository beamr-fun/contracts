// SPDX-License-Identifier: UNLICENSED

import {
    PoolConfig,
    PoolERC20Metadata
} from
    "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";


pragma solidity ^0.8.23;

contract BeamR {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;

        PoolERC20Metadata memory poolMD = PoolERC20Metadata({
            name: "BeamR Pool",
            symbol: "BRP",
            decimals: 18
        });
    }

    function increment() public {
        number++;
    }
}
