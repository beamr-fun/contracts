// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {
    PoolConfig,
    PoolERC20Metadata
} from "@superfluid/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SuperTokenV1Library} from "@superfluid/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {IBeamR} from "../interfaces/IBeamR.sol";
import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract BeamR is IBeamR, Initializable, Ownable, AccessControl {
    using SuperTokenV1Library for ISuperToken;

    bytes32 public constant ROOT_ADMIN_ROLE = keccak256("ROOT_ADMIN_ROLE");
    bytes32 public constant POOL_ADMIN_ROLE = keccak256("POOL_ADMIN_ROLE");

    function createPool(
        ISuperToken _poolSuperToken,
        PoolConfig memory _poolConfig,
        PoolERC20Metadata memory _erc20Metadata,
        Member[] memory _members,
        address _admin,
        Metadata memory _metadata
    ) external returns (ISuperfluidPool beamPool) {
        require(_isRole(POOL_ADMIN_ROLE, _admin), Unauthorized());

        beamPool = SuperTokenV1Library.createPoolWithCustomERC20Metadata(
            _poolSuperToken, address(this), _poolConfig, _erc20Metadata
        );

        emit PoolCreated(address(beamPool), address(_poolSuperToken), _poolConfig, _metadata);

        _updateMembersUnits(beamPool, _members);
    }

    function _updateMembersUnits(ISuperfluidPool _gdaPool, Member[] memory _members) internal {
        for (uint256 i; i < _members.length;) {
            _gdaPool.updateMemberUnits(_members[i].account, _members[i].units);

            unchecked {
                i++;
            }
        }
    }

    function _isRole(bytes32 _role, address _account) internal view returns (bool) {
        require(_role == ROOT_ADMIN_ROLE || _role == POOL_ADMIN_ROLE, "Invalid role");

        return hasRole(_role, _account);
    }
}
