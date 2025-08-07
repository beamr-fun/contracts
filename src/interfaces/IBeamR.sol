// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// import {
//     ISuperfluidPool,
//     ISuperToken
// } from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {PoolConfig} from
// PoolERC20Metadata
"@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

interface IBeamR {
    struct Metadata {
        uint256 protocol;
        string pointer;
    }

    struct Member {
        address account;
        uint128 units;
    }

    event PoolCreated(address pool, address token, PoolConfig config, Metadata metadata);

    error Unauthorized();
}
