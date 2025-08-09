// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface IBeamR {
    // -------- Types --------
    struct Metadata {
        uint256 protocol;
        string pointer;
    }

    struct Member {
        address account;
        uint128 units;
    }

    // -------- Role ids (for convenience) --------
    // Must match the contract’s values
    function ROOT_ADMIN_ROLE() external pure returns (bytes32);
    function ADMIN_ROLE() external pure returns (bytes32);

    // -------- Events --------
    event PoolCreated(address pool, address token, PoolConfig config, address creator, Metadata metadata);
    event PoolMetadataUpdated(address pool, Metadata metadata);

    // -------- Errors --------
    error Unauthorized();

    // -------- External API --------
    function createPool(
        ISuperToken _poolSuperToken,
        PoolConfig memory _poolConfig,
        PoolERC20Metadata memory _erc20Metadata,
        Member[] memory _members,
        address _creator,
        Metadata memory _metadata
    ) external returns (ISuperfluidPool beamPool);

    function updateMemberUnits(Member[] memory _members, address[] memory poolAddresses) external;

    function rescuePoolCreator(address _poolAddress, address _newCreator, address _currentCreator) external;

    function updateMetadata(address _poolAddress, Metadata memory _metadata) external;

    function poolAdminKey(address _poolAddress) external pure returns (bytes32);
}
