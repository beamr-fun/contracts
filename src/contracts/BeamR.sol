// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SuperTokenV1Library} from "@superfluid/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {IBeamR} from "../interfaces/IBeamR.sol";
import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

// import {GDAv1Forwarder} from "@superfluid/ethereum-contracts/contracts/utils/GDAv1Forwarder.sol";

contract BeamR is IBeamR, AccessControl {
    using SuperTokenV1Library for ISuperToken;

    bytes32 public constant ROOT_ADMIN_ROLE = keccak256("ROOT_ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(address[] memory _poolAdmins, address[] memory _rootAdmins) {
        for (uint256 i; i < _poolAdmins.length;) {
            _setupRole(ADMIN_ROLE, _poolAdmins[i]);
            unchecked {
                i++;
            }
        }

        for (uint256 i; i < _rootAdmins.length;) {
            _setupRole(ROOT_ADMIN_ROLE, _rootAdmins[i]);
            unchecked {
                i++;
            }
        }
    }

    function createPool(
        ISuperToken _poolSuperToken,
        PoolConfig memory _poolConfig,
        PoolERC20Metadata memory _erc20Metadata,
        Member[] memory _members,
        address _admin,
        address _creator,
        Metadata memory _metadata
    ) external returns (ISuperfluidPool beamPool) {
        if (!_isValidRole(ADMIN_ROLE, _admin)) {
            revert Unauthorized();
        }

        beamPool = SuperTokenV1Library.createPoolWithCustomERC20Metadata(
            _poolSuperToken, address(this), _poolConfig, _erc20Metadata
        );

        _setupRole(_poolAdminKey(address(beamPool)), _creator);

        emit PoolCreated(address(beamPool), address(_poolSuperToken), _poolConfig, _creator, _metadata);

        _updateMembersUnits(beamPool, _members);
    }

    function manageRole(bytes32 _targetRole, address _account, address _poolAddress, bool _grant) external {
        // ONLY ROOT_ADMIN, can grant or revoke ROOT_ADMIN_ROLE
        if (_targetRole == ROOT_ADMIN_ROLE && !hasRole(ROOT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        // ONLY ADMIN_ROLE and ROOT_ADMIN_ROLE can grant or revoke ADMIN_ROLE
        if (_targetRole == ADMIN_ROLE && (!hasRole(ROOT_ADMIN_ROLE, msg.sender)) && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        // ONLY POOL_ADMIN, ROOT_ADMIN, or ADMIN_ROLE can grant or revoke POOL_ADMIN_ROLE
        if (
            _targetRole == _poolAdminKey(_poolAddress)
                && (
                    !hasRole(ADMIN_ROLE, msg.sender) && !hasRole(ROOT_ADMIN_ROLE, msg.sender)
                        && !hasRole(_targetRole, msg.sender)
                )
        ) {
            revert Unauthorized();
        }

        if (_grant) {
            _setupRole(_targetRole, _account);
        } else {
            _revokeRole(_targetRole, _account);
        }
    }

    function updateMemberUnits(Member[] memory _members, address _poolAddress) external {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !isPoolAdmin(msg.sender, _poolAddress)) {
            revert Unauthorized();
        }

        ISuperfluidPool gdaPool = ISuperfluidPool(_poolAddress);

        _updateMembersUnits(gdaPool, _members);
    }

    function _updateMembersUnits(ISuperfluidPool _gdaPool, Member[] memory _members) internal {
        for (uint256 i; i < _members.length;) {
            _gdaPool.updateMemberUnits(_members[i].account, _members[i].units);

            unchecked {
                i++;
            }
        }
    }

    function isPoolAdmin(address _account, address _poolAddress) public view returns (bool) {
        return hasRole(_poolAdminKey(_poolAddress), _account);
    }

    function _isValidRole(bytes32 _role, address _account) internal view returns (bool) {
        if (_role != ROOT_ADMIN_ROLE && _role != ADMIN_ROLE) {
            revert Unauthorized();
        }

        return hasRole(_role, _account);
    }

    function _poolAdminKey(address _poolAddress) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_poolAddress));
    }
}
