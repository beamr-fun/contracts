// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

import {SuperTokenV1Library} from "@superfluid/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract BeamR {
    using SuperTokenV1Library for ISuperToken;

    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;

        PoolERC20Metadata memory poolMD = PoolERC20Metadata({name: "BeamR Pool", symbol: "BRP", decimals: 18});

        ISuperfluidPool pool = ISuperfluidPool(address(this));
    }

    function increment() public {
        number++;
    }
}
