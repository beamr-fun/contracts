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

    /// @notice Arbitrary off-chain metadata pointer with a protocol id.
    /// @dev `protocol` identifies how to interpret `pointer` (e.g., IPFS, HTTPS).
    struct Metadata {
        uint256 protocol;
        string pointer;
    }

    /// @notice Member record for unit-based distributions.
    /// @param account Member address.
    /// @param units Unit weight used by the pool.
    struct Member {
        address account;
        uint128 units;
    }

    // -------- Role ids (for convenience) --------
    // Must match the contract’s values
    function ROOT_ADMIN_ROLE() external pure returns (bytes32);
    function ADMIN_ROLE() external pure returns (bytes32);

    // -------- Events --------

    /// @notice Emitted when the contract is initialized.
    /// @param adminRole The ADMIN_ROLE role id.
    /// @param rootAdminRole The ROOT_ADMIN_ROLE role id.
    event Initialized(bytes32 adminRole, bytes32 rootAdminRole);

    /// @notice Emitted when a new pool is created.
    /// @param pool The pool address.
    /// @param token The SuperToken backing the pool.
    /// @param config The pool config used at creation.
    /// @param creator Address granted the pool admin role.
    /// @param poolAdminRole The pool-specific admin role id.
    /// @param metadata Off-chain pointer/schema info.
    event PoolCreated(
        address pool, address token, PoolConfig config, address creator, bytes32 poolAdminRole, Metadata metadata
    );
    /// @notice Emitted when pool metadata is updated.
    /// @param pool The pool whose metadata changed.
    /// @param metadata New off-chain pointer/schema info.
    event PoolMetadataUpdated(address pool, Metadata metadata);

    // -------- Errors --------

    /// @notice Thrown when the caller lacks required permissions.
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
