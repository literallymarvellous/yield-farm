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

    /// @notice The underlying token the Vault accepts.
    ERC20 public immutable UNDERLYING;

    /// @notice The Compound cToken the Vault accepts.
    CErc20 public immutable cToken;

    /// @notice The underlying token that have been deposited into compound strategy
    uint256 private _totalStrategyHoldings;

    /// @notice Creates a new Vault with ERC20 Token as the underlying asset
    /// @dev An Owner is initialized
    /// @param _UNDERLYING ERC20 Token to deposit into vault as the underlying token
    /// @param _token address of complimentary compound cToken to the underlying token. eg. USDC -> cUSDC
    /// @param _owner address of the owner of the contract
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

    /// @notice Deposits an amount of underlying tokens into the vault
    /// @dev Half of the deposit is moved into Compound strategy using the cToken
    /// @param assets amount of the underlying tokens
    /// @param receiver address receiving the minted shares
    /// @return shares amount of vault tokens minted to msg.sender
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

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(depositAssets, shares);
    }

    /// @notice Depsoits a calculated amount of undelying tokens into vault based on minted vault tokens.
    /// @dev Half of the deposit calculated from the minted shares is moved into the Compound strategy
    /// @param shares amount of the vault shares to mint
    /// @param receiver address receiving the minted shares
    /// @return assets equivalent amount of underlying tokens to minted shares
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

    /// @notice Transfers underlying token from vault to Compound strategy
    /// @dev Executes in mint/deposit function
    /// @param _assets underlying tokens to depsoit
    function afterDeposit(uint256 _assets, uint256) internal override {
        UNDERLYING.approve(address(cToken), _assets);
        require(cToken.mint(_assets) == 0, "COMP: Deposit Failed");
    }

    /// @notice Redeem vault tokens ie.shares for deposited underlying tokens
    /// @dev total yield from Compound is calculated before withdrawal
    /// @param shares amount of vault tokens
    /// @param receiver recipient address of assets
    /// @param owner owner address of vault tokens ie. shares
    /// @return assets amount of underlying tokens recieved
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

    /// @notice Transfers underlying tokens from Compound strategy to Vault
    /// @dev Executes in withdraw/redeem functions if vault lacks funds.
    /// @param _assets amount of underlying tokens
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

    /// @notice Returns amount of underlying token in both the Vault and Compound strategy
    /// @dev Used in calculations for the amount of the underlying token/shares to deposit/withdraw
    /// @return total amount of underlying tokens
    function totalAssets() public view override returns (uint256 total) {
        total = _totalStrategyHoldings + totalFloat();
    }

    /// @notice Returns the amount of underlying tokens that idly sit in the Vault.
    /// @return The amount of underlying tokens that sit idly in the Vault.
    function totalFloat() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    /// @notice Compound strategy yield info
    /// @return exchangeRate rate from cToken to underlying token
    /// @return supplyRate rate of yield on deposit per block
    function getCompStrategyInfo()
        external
        returns (uint256 exchangeRate, uint256 supplyRate)
    {
        // Amount of current exchange rate from cToken to underlying
        exchangeRate = cToken.exchangeRateCurrent();
        // Amount added to you supply balance this block
        supplyRate = cToken.supplyRatePerBlock();
    }

    /// @notice Returns amount of underlying token held in Compound strategy
    /// @return amount of underlying token ie. cToken * exchangeRate
    function compBalanceOfUnderlying() public returns (uint256) {
        return cToken.balanceOfUnderlying(address(this));
    }

    /// @notice Updates _totalStrategyHoldings
    /// @dev sets _totalStrategyHoldings as amount of underlying token held in Compound strategy
    function updateTotalStrategyHoldings() external {
        _totalStrategyHoldings = compBalanceOfUnderlying();
    }
}
