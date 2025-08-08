// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {PoolConfig} from
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

    event PoolCreated(address pool, address token, PoolConfig config, address creator, Metadata metadata);

    event PoolMetadataUpdated(address pool, Metadata metadata);

    error Unauthorized();
}
