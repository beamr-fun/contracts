// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {BeamR} from "../src/contracts/BeamR.sol";

contract DeployBeamRImplementation is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRI_K");
        address implementation;

        vm.startBroadcast(deployerPrivateKey);

        BeamR _implementation = new BeamR();

        implementation = address(_implementation);

        vm.stopBroadcast();

        console2.log("BeamR implementation deployed at:", implementation);
    }
}
