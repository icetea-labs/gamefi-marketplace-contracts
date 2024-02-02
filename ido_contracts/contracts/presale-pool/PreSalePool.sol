// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "../interfaces/IERC20.sol";
import "../interfaces/IPoolFactory.sol";
import "../libraries/TransferHelper.sol";
import "../libraries/Ownable.sol";
import "../libraries/ReentrancyGuard.sol";
import "../libraries/SafeMath.sol";
import "../libraries/Pausable.sol";
import "../extensions/Whitelist.sol";

contract PreSalePool is Ownable, ReentrancyGuard, Pausable, Whitelist {
    using SafeMath for uint256;

    struct OfferedCurrency {
        uint256 decimals;
        uint256 rate;
    }

    struct UserRefundToken {
        uint256 currencyAmount;
        address currency;
        bool isClaimed;
    }

    // The token being sold
    IERC20 public token;

    // The address of factory contract
    address public factory;

    // The address of signer account
    address public signer;

    // Address where funds are collected
    address public fundingWallet;

    // Timestamps when token started to sell
    uint256 public openTime = block.timestamp;

    // Timestamps when token stopped to sell
    uint256 public closeTime;

    // Amount of wei raised
    uint256 public weiRaised = 0;

    // Amount of token sold
    uint256 public tokenSold = 0;

    // Amount of token sold
    uint256 public totalUnclaimed = 0;

    // Number of token user purchased
    mapping(address => uint256) public userPurchased;

    // Number of token user claimed
    mapping(address => uint256) public userClaimed;

    // Number of token user purchased
    mapping(address => mapping (address => uint)) public investedAmountOf;

    // Get offered currencies
    mapping(address => OfferedCurrency) public offeredCurrencies;

    // Pool extensions
    bool public useWhitelist = true;

    // User refund token
    mapping(address => UserRefundToken) public userRefundToken;

    // Total amount of user refund by currency
    uint256 public totalRefundCurrency = 0;

    // Amount of user refund by currency
    uint256 public refundCurrency = 0;

    // Allow owner change the purchased state
    bool public allowChangePurchasedState = false;

    // Allow owner change the claimed state
    bool public claimable = true;

    // Operation fee for refund
    uint256 public staticFee = 0; // $
    uint256 public dynamicFeePerMil = 0; // per a thousand

    // -----------------------------------------
    // Lauchpad Starter's event
    // -----------------------------------------
    event PresalePoolCreated(
        address token,
        uint256 openTime,
        uint256 closeTime,
        address offeredCurrency,
        uint256 offeredCurrencyDecimals,
        uint256 offeredCurrencyRate,
        address wallet,
        address owner
    );
    event TokenPurchaseByEther(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );
    event TokenPurchaseByToken(
        address indexed purchaser,
        address indexed beneficiary,
        address token,
        uint256 value,
        uint256 amount
    );

    event TokenClaimed(address user, uint256 amount);
    event RefundedIcoToken(address wallet, uint256 amount);
    event RefundedIcoCurrency(address wallet, uint256 amount);
    event PoolStatsChanged();
    event TokenChanged(address token);
    event RefundToken(address user, uint256 currencyAmount, address currency);
    event ClaimRefund(address user, uint256 currencyAmount, address currency);

    // -----------------------------------------
    // Constructor
    // -----------------------------------------
    constructor() {
        factory = msg.sender;
    }

    /**
     * @param _token Address of the token being sold
     * @param _duration Duration of ICO Pool
     * @param _openTime When ICO Started
     * @param _offeredCurrency Address of offered token
     * @param _offeredCurrencyDecimals Decimals of offered token
     * @param _offeredRate Number of currency token units a buyer gets
     * @param _wallet Address where collected funds will be forwarded to
     * @param _signer Address where collected funds will be forwarded to
     */
    function initialize(
        address _token,
        uint256 _duration,
        uint256 _openTime,
        address _offeredCurrency,
        uint256 _offeredRate,
        uint256 _offeredCurrencyDecimals,
        address _wallet,
        address _signer
    ) external {
        require(msg.sender == factory, "POOL::UNAUTHORIZED");

        token = IERC20(_token);
        openTime = _openTime;
        closeTime = _openTime.add(_duration);
        fundingWallet = _wallet;
        owner = tx.origin;
        paused = false;
        signer = _signer;

        offeredCurrencies[_offeredCurrency] = OfferedCurrency({
            rate: _offeredRate,
            decimals: _offeredCurrencyDecimals
            });

        emit PresalePoolCreated(
            _token,
            _openTime,
            closeTime,
            _offeredCurrency,
            _offeredCurrencyDecimals,
            _offeredRate,
            _wallet,
            owner
        );
    }

    /**
     * @notice Returns the conversion rate when user buy by offered token
     * @return Returns only a fixed number of rate.
     */
    function getOfferedCurrencyRate(address _token) public view returns (uint256) {
        return offeredCurrencies[_token].rate;
    }

    /**
     * @notice Returns the conversion rate decimals when user buy by offered token
     * @return Returns only a fixed number of decimals.
     */
    function getOfferedCurrencyDecimals(address _token) public view returns (uint256) {
        return offeredCurrencies[_token].decimals;
    }

    /**
     * @notice Return the available tokens for purchase
     * @return availableTokens Number of total available
     */
    function getAvailableTokensForSale() public view returns (uint256 availableTokens) {
        return token.balanceOf(address(this)).sub(totalUnclaimed);
    }

    /**
     * @notice Owner can set the offered token conversion rate. Receiver tokens = tradeTokens * tokenRate / 10 ** etherConversionRateDecimals
     * @param _rate Fixed number of ether rate
     * @param _decimals Fixed number of ether rate decimals
     */
    function setOfferedCurrencyRateAndDecimals(address _token, uint256 _rate, uint256 _decimals)
    external
    onlyOwner
    {
        offeredCurrencies[_token].rate = _rate;
        offeredCurrencies[_token].decimals = _decimals;
        emit PoolStatsChanged();
    }

    /**
     * @notice Owner can set the offered token conversion rate. Receiver tokens = tradeTokens * tokenRate / 10 ** etherConversionRateDecimals
     * @param _rate Fixed number of rate
     */
    function setOfferedCurrencyRate(address _token, uint256 _rate) external onlyOwner {
        require(offeredCurrencies[_token].rate != _rate, "POOL::RATE_INVALID");
        offeredCurrencies[_token].rate = _rate;
        emit PoolStatsChanged();
    }

    /**
     * @notice Owner can set the offered token conversion rate. Receiver tokens = tradeTokens * tokenRate / 10 ** etherConversionRateDecimals
     * @param _newSigner Address of new signer
     */
    function setNewSigner(address _newSigner) external onlyOwner {
        require(signer != _newSigner, "POOL::SIGNER_INVALID");
        signer = _newSigner;
    }

    /**
     * @notice Owner can set the offered token conversion rate. Receiver tokens = tradeTokens * tokenRate / 10 ** etherConversionRateDecimals
     * @param _decimals Fixed number of decimals
     */
    function setOfferedCurrencyDecimals(address _token, uint256 _decimals) external onlyOwner {
        require(offeredCurrencies[_token].decimals != _decimals, "POOL::RATE_INVALID");
        offeredCurrencies[_token].decimals = _decimals;
        emit PoolStatsChanged();
    }

    /**
     * @notice Owner can set the close time (time in seconds). User can buy before close time.
     * @param _closeTime Value in uint256 determine when we stop user to by tokens
     */
    function setCloseTime(uint256 _closeTime) external onlyOwner() {
        require(_closeTime >= block.timestamp, "POOL::INVALID_TIME");
        closeTime = _closeTime;
        emit PoolStatsChanged();
    }

    /**
     * @notice Owner can set the open time (time in seconds). User can buy after open time.
     * @param _openTime Value in uint256 determine when we allow user to by tokens
     */
    function setOpenTime(uint256 _openTime) external onlyOwner() {
        openTime = _openTime;
        emit PoolStatsChanged();
    }

    /**
     * @notice Owner can set extentions.
     * @param _whitelist Value in bool. True if using whitelist
     */
    function setPoolExtentions(bool _whitelist) external onlyOwner() {
        useWhitelist = _whitelist;
        emit PoolStatsChanged();
    }

    function setClaimable(bool _isAllow) external onlyOwner {
        claimable = _isAllow;
    }

    function setAllowChangePurchasedState(bool _isAllow) external onlyOwner {
        allowChangePurchasedState = _isAllow;
    }

    function setPurchasingState(
        address _token,
        address[] calldata _candidates,
        uint256[] calldata _amounts
    ) external onlyOwner {
        require(allowChangePurchasedState, "POOL::PURCHASE_MODE_NOT_ALLOWED");
        require(
            offeredCurrencies[_token].rate != 0,
            "POOL::PURCHASE_METHOD_NOT_ALLOWED"
        );
        require(
            _candidates.length == _amounts.length,
            "POOL::INVALID_DATA_LENGTH"
        );

        for (uint256 i; i < _candidates.length; i++) {
            address _candidate = _candidates[i];
            uint256 _amount = _amounts[i];

            _preValidatePurchase(_candidate, _amount);

            uint256 currencyAmount = _convertTokenAmountToCurrencyAmount(_token, _amount);
            tokenSold = tokenSold.add(_amount);
            userPurchased[_candidate] = userPurchased[_candidate].add(_amount);
            totalUnclaimed = totalUnclaimed.add(_amount);
            weiRaised = weiRaised.add(currencyAmount);
            investedAmountOf[_token][_candidate] = investedAmountOf[_token][_candidate].add(currencyAmount);

            emit TokenPurchaseByToken(
                _candidate,
                _candidate,
                _token,
                0,
                _amount
            );
        }

        allowChangePurchasedState = false;
    }

    function changeSaleToken(address _token) external onlyOwner() {
        require(_token != address(0));
        token = IERC20(_token);
        emit TokenChanged(_token);
    }

    function setFee(uint256 _staticFee, uint256 _dynamicFeePerMil) external onlyOwner() {
        if (_staticFee > 0) {
            dynamicFeePerMil = 0;
            staticFee = _staticFee;
            return;
        }

        if (_dynamicFeePerMil > 0) {
            dynamicFeePerMil = _dynamicFeePerMil;
            staticFee = 0;
            return;
        }

        dynamicFeePerMil = 0;
        staticFee = 0;
    }

    function buyTokenByEtherWithPermission(
        address _beneficiary,
        address _candidate,
        uint256 _maxAmount,
        uint256 _minAmount,
        bytes memory _signature
    ) public payable whenNotPaused nonReentrant {
        require(!allowChangePurchasedState, "POOL::PURCHASE_MODE_NOT_ALLOWED");
        require(userRefundToken[_candidate].currencyAmount == 0, "POOL::USER_REFUNDED");
        uint256 weiAmount = msg.value;

        require(offeredCurrencies[address(0)].rate != 0, "POOL::PURCHASE_METHOD_NOT_ALLOWED");

        _preValidatePurchase(_beneficiary, weiAmount);

        require(_validPurchase(), "POOL::ENDED");
        require(_verifyWhitelist(_candidate, _maxAmount, _minAmount, _signature), "POOL:INVALID_SIGNATURE");

        // calculate token amount to be created
        uint256 tokens = _getOfferedCurrencyToTokenAmount(address(0), weiAmount);
        require(getAvailableTokensForSale() >= tokens, "POOL::NOT_ENOUGH_TOKENS_FOR_SALE");
        require(tokens >= _minAmount || userPurchased[_candidate].add(tokens) >= _minAmount, "POOL::MIN_AMOUNT_UNREACHED");
        require(userPurchased[_candidate].add(tokens) <= _maxAmount, "POOL::PURCHASE_AMOUNT_EXCEED_ALLOWANCE");

        _forwardFunds(weiAmount);

        _updatePurchasingState(weiAmount, tokens);

        investedAmountOf[address(0)][_candidate] = investedAmountOf[address(0)][_candidate].add(weiAmount);

        emit TokenPurchaseByEther(msg.sender, _beneficiary, weiAmount, tokens);
    }

    function buyTokenByTokenWithPermission(
        address _beneficiary,
        address _token,
        uint256 _amount,
        address _candidate,
        uint256 _maxAmount,
        uint256 _minAmount,
        bytes memory _signature
    ) public whenNotPaused nonReentrant {
        require(_token != address(0), "POOL::PURCHASE_TOKEN_NOT_ALLOWED");
        require(!allowChangePurchasedState, "POOL::PURCHASE_MODE_NOT_ALLOWED");
        require(userRefundToken[_candidate].currencyAmount == 0, "POOL::USER_REFUNDED");
        require(offeredCurrencies[_token].rate != 0, "POOL::PURCHASE_METHOD_NOT_ALLOWED");
        require(_validPurchase(), "POOL::ENDED");
        require(_verifyWhitelist(_candidate, _maxAmount, _minAmount, _signature), "POOL:INVALID_SIGNATURE");

        _preValidatePurchase(_beneficiary, _amount);

        uint256 tokens = _getOfferedCurrencyToTokenAmount(_token, _amount);
        require(getAvailableTokensForSale() >= tokens, "POOL::NOT_ENOUGH_TOKENS_FOR_SALE");
        require(tokens >= _minAmount || userPurchased[_candidate].add(tokens) >= _minAmount, "POOL::MIN_AMOUNT_UNREACHED");
        require(userPurchased[_candidate].add(tokens) <= _maxAmount, "POOL:PURCHASE_AMOUNT_EXCEED_ALLOWANCE");

        _forwardTokenFunds(_token, _amount);

        _updatePurchasingState(_amount, tokens);

        investedAmountOf[_token][_candidate] = investedAmountOf[_token][_candidate].add(_amount);

        emit TokenPurchaseByToken(
            msg.sender,
            _beneficiary,
            _token,
            _amount,
            tokens
        );
    }

    /**
     * @notice Return true if pool has ended
     * @dev User cannot purchase / trade tokens when isFinalized == true
     * @return true if the ICO Ended.
     */
    function isFinalized() public view returns (bool) {
        return block.timestamp >= closeTime;
    }

    /**
     * @notice Owner can receive their remaining tokens when ICO Ended
     * @dev  Can refund remainning token if the ico ended
     * @param _wallet Address wallet who receive the remainning tokens when Ico end
     */
    function refundRemainingTokens(address _wallet)
    external
    onlyOwner
    {
        require(isFinalized(), "POOL::ICO_NOT_ENDED");
        require(token.balanceOf(address(this)) > 0, "POOL::EMPTY_BALANCE");

        uint256 remainingTokens = getAvailableTokensForSale();
        _deliverTokens(_wallet, remainingTokens);
        emit RefundedIcoToken(_wallet, remainingTokens);
    }

    /**
      * @notice Owner can receive their remaining currency
      * @dev  Can refund remainning currency if user can't claim refund
      * @param _wallet Address wallet who receive the remainning currency
      */
    function refundRemainingCurrency(address _wallet, address _currency) external onlyOwner {
        require(isFinalized(), "POOL::NOT_FINALIZED");

        uint256 contractBalance = address(this).balance;

        if(_currency != address(0)){
            contractBalance = IERC20(_currency).balanceOf(address(this));
        }

        require(contractBalance > 0, "POOL::EMPTY_BALANCE");
        _deliverCurrency(_currency, _wallet, contractBalance);
        emit RefundedIcoCurrency(_wallet, contractBalance);
    }

    /**
     * @notice User can receive their tokens when pool finished
     */
    function claimTokens(address _candidate, uint256 _amount, bytes memory _signature) nonReentrant public {
        require(claimable, "POOL::NOT_CLAIMABLE");
        require(_verifyClaimToken(_candidate, _amount, _signature), "POOL::NOT_ALLOW_TO_CLAIM");
        require(isFinalized(), "POOL::NOT_FINALIZED");
        require(_amount >= userClaimed[_candidate], "POOL::AMOUNT_MUST_GREATER_THAN_CLAIMED");

        uint256 maxClaimAmount = userPurchased[_candidate].sub(userClaimed[_candidate]);

        uint claimAmount = _amount.sub(userClaimed[_candidate]);

        if (claimAmount > maxClaimAmount) {
            claimAmount = maxClaimAmount;
        }

        userClaimed[_candidate] = userClaimed[_candidate].add(claimAmount);

        _deliverTokens(msg.sender, claimAmount);

        totalUnclaimed = totalUnclaimed.sub(claimAmount);

        emit TokenClaimed(msg.sender, claimAmount);
    }

    /**
      * @notice User can request refund ido tokens to receipt offered currency
     */
    function refundTokens(address _candidate, address _currency, uint256 _deadline, bytes memory _signature) nonReentrant public {
        require(isFinalized(), "POOL::NOT_FINALIZED");
        require(block.timestamp <= _deadline, "POOL:REFUND_ENDED");
        require(userClaimed[_candidate] == 0 && userPurchased[_candidate] > 0, "POOL::NOT_ALLOW_TO_REFUND");

        require(_verifyRefundToken(_candidate, _currency, _deadline, _signature), "POOL:INVALID_SIGNATURE");

        uint256 currencyAmount = investedAmountOf[_currency][_candidate];
        require(currencyAmount > 0, "POOL::NOT_ALLOW_CURRENCY_TO_REFUND");

        userRefundToken[_candidate] = UserRefundToken({
            currencyAmount: currencyAmount,
            currency: _currency,
            isClaimed: false
            });

        uint256 refundTokenAmount = userPurchased[_candidate];
        totalRefundCurrency = totalRefundCurrency.add(currencyAmount);
        refundCurrency = refundCurrency.add(currencyAmount);

        totalUnclaimed = totalUnclaimed.sub(refundTokenAmount);
        tokenSold = tokenSold.sub(refundTokenAmount);
        userPurchased[_candidate] = 0;
        weiRaised = weiRaised.sub(currencyAmount);
        investedAmountOf[_currency][_candidate] = 0;

        emit RefundToken(_candidate, currencyAmount, _currency);
    }

    /**
      * @notice User claim request refund ido tokens
     */
    function claimRefundTokens(address _candidate, address _currency, bytes memory _signature) nonReentrant public {
        require(isFinalized(), "POOL::NOT_FINALIZED");
        require(userRefundToken[_candidate].currencyAmount > 0 && !userRefundToken[_candidate].isClaimed, "POOL::NOT_ALLOW_TO_CLAIM_REFUND");
        require(_verifyClaimRefundToken(_candidate, _currency, _signature), "POOL:INVALID_SIGNATURE");

        refundCurrency = refundCurrency.sub(userRefundToken[_candidate].currencyAmount);
        userRefundToken[_candidate].isClaimed = true;

        uint256 claimAmount = userRefundToken[_candidate].currencyAmount;
        if (dynamicFeePerMil > 0) {
            claimAmount = claimAmount.mul(dynamicFeePerMil).div(1000);
        }

        if (staticFee > 0) {
            claimAmount = claimAmount.sub(staticFee);
        }

        require(_currency == address(0) ? address(this).balance >= claimAmount : IERC20(_currency).balanceOf(address(this)) >= claimAmount, "POOL::NOT_ENOUGH_CURRENCY_FOR_CLAIM_REFUND");
        _deliverCurrency(_currency, _candidate, claimAmount);

        emit ClaimRefund(_candidate, claimAmount, _currency);
    }

    /**
      * @notice Get total refund currency
     */
    function getTotalRefundToken(address _token)
    public
    view
    returns (uint256)
    {
        return _getOfferedCurrencyToTokenAmount(_token, totalRefundCurrency);
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount)
    internal
    pure
    {
        require(_beneficiary != address(0), "POOL::INVALID_BENEFICIARY");
        require(_weiAmount != 0, "POOL::INVALID_WEI_AMOUNT");
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _amount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getOfferedCurrencyToTokenAmount(address _token, uint256 _amount)
    internal
    view
    returns (uint256)
    {
        uint256 rate = getOfferedCurrencyRate(_token);
        uint256 decimals = getOfferedCurrencyDecimals(_token);
        return _amount.mul(rate).div(10**decimals);
    }

    function _convertTokenAmountToCurrencyAmount(address _token, uint256 _tokenAmount)
    internal
    view
    returns (uint256)
    {
        uint256 rate = getOfferedCurrencyRate(_token);
        uint256 decimals = getOfferedCurrencyDecimals(_token);
        return _tokenAmount.mul(10**decimals).div(rate);
    }

    function _deliverTokens(address _beneficiary, uint256 _tokenAmount)
    internal
    {
        token.transfer(_beneficiary, _tokenAmount);
    }

    function _deliverCurrency(address _currency, address _beneficiary, uint256 _currencyAmount)
    internal
    {
        if(_currency == address(0)){
            _transfer(_beneficiary, _currencyAmount);
        } else {
            TransferHelper.safeTransfer(
                _currency,
                _beneficiary,
                _currencyAmount
            );
        }
    }

    function _forwardFunds(uint256 _value) internal {
        address payable wallet = address(uint160(fundingWallet));
        (bool success, ) = wallet.call{value: _value}("");
        require(success, "POOL::WALLET_TRANSFER_FAILED");
    }

    function _forwardTokenFunds(address _token, uint256 _amount) internal {
        TransferHelper.safeTransferFrom(_token, msg.sender, fundingWallet, _amount);
    }

    function _updatePurchasingState(uint256 _weiAmount, uint256 _tokens)
    internal
    {
        weiRaised = weiRaised.add(_weiAmount);
        tokenSold = tokenSold.add(_tokens);
        userPurchased[msg.sender] = userPurchased[msg.sender].add(_tokens);
        totalUnclaimed = totalUnclaimed.add(_tokens);
    }

    function _validPurchase() internal view returns (bool) {
        bool withinPeriod =
        block.timestamp >= openTime && block.timestamp <= closeTime;
        return withinPeriod;
    }

    function _transfer(address _to, uint256 _amount) private {
        address payable payableAddress = address(uint160(_to));
        (bool success, ) = payableAddress.call{value: _amount}("");
        require(success, "POOL::TRANSFER_FEE_FAILED");
    }

    function _verifyWhitelist(
        address _candidate,
        uint256 _maxAmount,
        uint256 _minAmount,
        bytes memory _signature
    ) private view returns (bool) {
        require(msg.sender == _candidate, "POOL::WRONG_CANDIDATE");

        if (useWhitelist) {
            return (verify(signer, _candidate, _maxAmount, _minAmount, _signature));
        }
        return true;
    }

    function _verifyClaimToken(
        address _candidate,
        uint256 _amount,
        bytes memory _signature
    ) private view returns (bool) {
        require(msg.sender == _candidate, "POOL::WRONG_CANDIDATE");

        return (verifyClaimToken(signer, _candidate, _amount, _signature));
    }

    function _verifyRefundToken(
        address _candidate,
        address _currency,
        uint256 _deadline,
        bytes memory _signature
    ) private view returns (bool){
        require(msg.sender == _candidate, "POOL::WRONG_CANDIDATE");

        return (verifyRefundToken(signer, _candidate, _currency, _deadline, _signature));
    }

    function _verifyClaimRefundToken(
        address _candidate,
        address _currency,
        bytes memory _signature
    ) private view returns (bool){
        require(msg.sender == _candidate, "POOL::WRONG_CANDIDATE");

        return (verifyClaimRefundToken(signer, _candidate, _currency, _signature));
    }

    fallback() external {}

    receive() external payable {}
}
