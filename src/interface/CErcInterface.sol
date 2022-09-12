// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface CErc20 {
    function balanceOf(address) external view returns (uint256);

    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function balanceOfUnderlying(address) external returns (uint256);

    function redeem(uint256) external returns (uint256);

    function redeemUnderlying(uint256) external returns (uint256);

    function borrow(uint256) external returns (uint256);

    function borrowBalanceCurrent(address) external returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function repayBorrow(uint256) external returns (uint256);

    function liquidateBorrow(
        address borrower,
        uint256 amount,
        address collateral
    ) external returns (uint256);
}
