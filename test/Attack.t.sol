// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Attacker, IUniswapV2Factory, IUniswapV2Router02} from "../src/Attacker.sol";
import {IERC20} from "../src/ERC777.sol";
import {ERC777Like} from "../src/ERC777Like.sol";

contract AttackTest is Test {
    Attacker public attacker;
    ERC777Like public token;
    address public pair;
    
    IUniswapV2Router02 public router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address public alice;
    address public bob;

    function setUp() public {
        token = new ERC777Like();
        attacker = new Attacker(address(token));

        bob = makeAddr("Bob");
        alice = makeAddr("Alice");

        deal(WETH, alice, 30 ether);
        deal(address(token), alice, 5000 ether);
    
        // Create pair
        pair = IUniswapV2Factory(router.factory()).createPair(address(token), WETH);

        // Add liquidity
        vm.startPrank(alice);
        token.approve(address(router), 5000 ether);
        IERC20(WETH).approve(address(router), 30 ether);
        router.addLiquidity(address(token), WETH, 5000 ether, 30 ether, 1, 1, alice, block.timestamp);
        vm.stopPrank();
    }

    function testAddress() external {
        deal(WETH, bob, 30 ether);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(token);

        vm.startPrank(bob);
        IERC20(WETH).approve(address(attacker), 30 ether);
        attacker.start(5 ether);
        vm.stopPrank();
    }

}
