// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Auth} from "@solmate/auth/Auth.sol";
import {Owned} from "@solmate/auth/Owned.sol";
import {ERC4626} from "@solmate/mixins/ERC4626.sol";

import {SafeCastLib} from "@solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {CErc20} from "./interface/CErcInterface.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract AIMVault is ERC4626, Owned {
    using SafeCastLib for uint256;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    event TotalAssetsUpdate(uint256 amount);
    event TottalUnderlyingUpdate(uint256 amount);

    /// @notice The underlying token the Vault accepts.
    ERC20 public immutable UNDERLYING;

    /// @notice The Compound cToken the Vault accepts.
    CErc20 public immutable cToken;

    /// @notice The underlying token that have been deposited into compound strategy
    uint256 private _totalStrategyHoldings;

    constructor(
        ERC20 _UNDERLYING,
        address _token,
        address _owner
    )
        ERC4626(
            _UNDERLYING,
            string(abi.encodePacked("Aim ", _UNDERLYING.name(), " Vault")),
            string(abi.encodePacked("av", _UNDERLYING.symbol()))
        )
        Owned(_owner)
    {
        UNDERLYING = _UNDERLYING;
        cToken = CErc20(_token);
    }

    function deposit(uint256 assets, address receiver)
        public
        override
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // calculate the amount of assets to put into compound strategy
        uint256 depositAssets = assets / 2;
        _totalStrategyHoldings += depositAssets;

        // // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(depositAssets, shares);
    }

    function mint(uint256 shares, address receiver)
        public
        override
        returns (uint256 assets)
    {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // calculate the amount of assets to put into compound strategy
        uint256 depositAssets = assets / 2;
        _totalStrategyHoldings += depositAssets;

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(depositAssets, shares);
    }

    function afterDeposit(uint256 _assets, uint256) internal override {
        UNDERLYING.approve(address(cToken), _assets);
        require(cToken.mint(_assets) == 0, "COMP: Deposit Failed");
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max)
                allowance[owner][msg.sender] = allowed - shares;
        }

        _totalStrategyHoldings = compBalanceOfUnderlying();

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    function beforeWithdraw(uint256 _assets, uint256) internal override {
        uint256 _totalFloat = totalFloat();

        if (_totalFloat < _assets) {
            uint256 toRedeem = _assets - _totalFloat;
            _totalStrategyHoldings -= toRedeem;
            require(
                cToken.redeemUnderlying(toRedeem) == 0,
                "COMP: Redeem failed"
            );
        }
    }

    function totalAssets() public view override returns (uint256 total) {
        total = _totalStrategyHoldings + totalFloat();
    }

    /// @notice Returns the amount of underlying tokens that idly sit in the Vault.
    /// @return The amount of underlying tokens that sit idly in the Vault.
    function totalFloat() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    function getCompStrategyInfo()
        external
        returns (uint256 exchangeRate, uint256 supplyRate)
    {
        // Amount of current exchange rate from cToken to underlying
        exchangeRate = cToken.exchangeRateCurrent();
        // Amount added to you supply balance this block
        supplyRate = cToken.supplyRatePerBlock();
    }

    function compBalanceOfUnderlying() public returns (uint256) {
        return cToken.balanceOfUnderlying(address(this));
    }

    function updateTotalStrategyHoldings() external onlyOwner {
        _totalStrategyHoldings = compBalanceOfUnderlying();
    }
}
