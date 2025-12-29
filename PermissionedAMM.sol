// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PermissionedAMM
 * @dev Automated Market Maker for carbon credit trading with regulatory controls
 */
contract PermissionedAMM {
    // Structs
    struct LiquidityPool {
        uint256 poolId;
        address creator;
        address carbonTokenAddress;
        address pairingTokenAddress;
        uint256 carbonTokenReserve;
        uint256 pairingTokenReserve;
        uint256 lpTokenSupply;
        bool isActive;
        uint256 creationTimestamp;
    }

    struct LPTokenInfo {
        uint256 poolId;
        address holder;
        uint256 lpTokenBalance;
    }

    struct TradeRecord {
        uint256 tradeId;
        uint256 poolId;
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 tradeTimestamp;
    }

    // State variables
    mapping(uint256 => LiquidityPool) public liquidityPools;
    mapping(uint256 => mapping(address => uint256)) public lpTokenBalances;
    mapping(uint256 => uint256) public totalLPTokens;
    mapping(uint256 => uint256[]) public poolTrades;

    uint256 public poolCounter = 0;
    uint256 public tradeCounter = 0;
    uint256 public feePercentage = 25; // 0.25% fee (25 basis points)
    uint256 public constant PRECISION = 10000; // 1% = 100, 0.01% = 1

    address public carbonTokenAddress;
    address public admin;

    mapping(address => bool) public whitelistedTokens;
    mapping(address => bool) public approvedGenerators;

    // Events
    event LiquidityPoolCreated(
        uint256 indexed poolId,
        address indexed creator,
        address carbonToken,
        address pairingToken,
        uint256 initialCarbonReserve,
        uint256 initialPairingReserve,
        uint256 timestamp
    );

    event LiquidityAdded(
        uint256 indexed poolId,
        address indexed provider,
        uint256 carbonTokenAmount,
        uint256 pairingTokenAmount,
        uint256 lpTokensMinted,
        uint256 timestamp
    );

    event LiquidityRemoved(
        uint256 indexed poolId,
        address indexed provider,
        uint256 carbonTokenAmount,
        uint256 pairingTokenAmount,
        uint256 lpTokensBurned,
        uint256 timestamp
    );

    event SwapExecuted(
        uint256 indexed tradeId,
        uint256 indexed poolId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        uint256 timestamp
    );

    event FeeUpdated(uint256 newFeePercentage);
    event TokenWhitelisted(address indexed token);
    event TokenRemovedFromWhitelist(address indexed token);
    event GeneratorApproved(address indexed generator);
    event GeneratorRemovedFromApproved(address indexed generator);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier poolExists(uint256 _poolId) {
        require(liquidityPools[_poolId].creator != address(0), "Pool does not exist");
        _;
    }

    modifier onlyApprovedGenerator() {
        require(approvedGenerators[msg.sender], "Generator not approved");
        _;
    }

    // Constructor
    constructor(address _carbonTokenAddress) {
        carbonTokenAddress = _carbonTokenAddress;
        admin = msg.sender;
        whitelistedTokens[_carbonTokenAddress] = true;
    }

    // Admin functions
    function whitelistToken(address _token) external onlyAdmin {
        whitelistedTokens[_token] = true;
        emit TokenWhitelisted(_token);
    }

    function removeTokenFromWhitelist(address _token) external onlyAdmin {
        whitelistedTokens[_token] = false;
        emit TokenRemovedFromWhitelist(_token);
    }

    function approveGenerator(address _generator) external onlyAdmin {
        approvedGenerators[_generator] = true;
        emit GeneratorApproved(_generator);
    }

    function removeGeneratorFromApproved(address _generator) external onlyAdmin {
        approvedGenerators[_generator] = false;
        emit GeneratorRemovedFromApproved(_generator);
    }

    function setFeePercentage(uint256 _feePercentage) external onlyAdmin {
        require(_feePercentage < PRECISION, "Fee percentage too high");
        feePercentage = _feePercentage;
        emit FeeUpdated(_feePercentage);
    }

    // Create liquidity pool
    function createLiquidityPool(
        address _pairingTokenAddress,
        uint256 _initialCarbonAmount,
        uint256 _initialPairingAmount
    ) external onlyApprovedGenerator returns (uint256) {
        require(whitelistedTokens[_pairingTokenAddress], "Pairing token not whitelisted");
        require(_initialCarbonAmount > 0, "Carbon amount must be greater than 0");
        require(_initialPairingAmount > 0, "Pairing amount must be greater than 0");

        uint256 poolId = poolCounter++;

        liquidityPools[poolId] = LiquidityPool({
            poolId: poolId,
            creator: msg.sender,
            carbonTokenAddress: carbonTokenAddress,
            pairingTokenAddress: _pairingTokenAddress,
            carbonTokenReserve: _initialCarbonAmount,
            pairingTokenReserve: _initialPairingAmount,
            lpTokenSupply: 0,
            isActive: true,
            creationTimestamp: block.timestamp
        });

        // Calculate initial LP tokens
        uint256 lpTokens = sqrt(_initialCarbonAmount * _initialPairingAmount);
        lpTokenBalances[poolId][msg.sender] = lpTokens;
        totalLPTokens[poolId] = lpTokens;

        emit LiquidityPoolCreated(
            poolId,
            msg.sender,
            carbonTokenAddress,
            _pairingTokenAddress,
            _initialCarbonAmount,
            _initialPairingAmount,
            block.timestamp
        );

        return poolId;
    }

    // Add liquidity
    function addLiquidity(
        uint256 _poolId,
        uint256 _carbonAmount,
        uint256 _pairingAmount
    ) external poolExists(_poolId) returns (uint256) {
        LiquidityPool storage pool = liquidityPools[_poolId];
        require(pool.isActive, "Pool not active");
        require(_carbonAmount > 0 && _pairingAmount > 0, "Amounts must be greater than 0");

        // Calculate LP tokens to mint
        uint256 lpTokens = ((_carbonAmount * totalLPTokens[_poolId]) /
            pool.carbonTokenReserve);

        pool.carbonTokenReserve += _carbonAmount;
        pool.pairingTokenReserve += _pairingAmount;
        lpTokenBalances[_poolId][msg.sender] += lpTokens;
        totalLPTokens[_poolId] += lpTokens;

        emit LiquidityAdded(
            _poolId,
            msg.sender,
            _carbonAmount,
            _pairingAmount,
            lpTokens,
            block.timestamp
        );

        return lpTokens;
    }

    // Remove liquidity
    function removeLiquidity(uint256 _poolId, uint256 _lpTokenAmount)
        external
        poolExists(_poolId)
        returns (uint256, uint256)
    {
        LiquidityPool storage pool = liquidityPools[_poolId];
        require(lpTokenBalances[_poolId][msg.sender] >= _lpTokenAmount, "Insufficient LP tokens");
        require(_lpTokenAmount > 0, "LP token amount must be greater than 0");

        // Calculate amounts to return
        uint256 carbonAmount = (_lpTokenAmount * pool.carbonTokenReserve) / totalLPTokens[_poolId];
        uint256 pairingAmount = (_lpTokenAmount * pool.pairingTokenReserve) / totalLPTokens[_poolId];

        pool.carbonTokenReserve -= carbonAmount;
        pool.pairingTokenReserve -= pairingAmount;
        lpTokenBalances[_poolId][msg.sender] -= _lpTokenAmount;
        totalLPTokens[_poolId] -= _lpTokenAmount;

        emit LiquidityRemoved(
            _poolId,
            msg.sender,
            carbonAmount,
            pairingAmount,
            _lpTokenAmount,
            block.timestamp
        );

        return (carbonAmount, pairingAmount);
    }

    // Swap tokens using constant product formula (x * y = k)
    function swap(
        uint256 _poolId,
        address _tokenIn,
        uint256 _amountIn
    ) external poolExists(_poolId) returns (uint256) {
        LiquidityPool storage pool = liquidityPools[_poolId];
        require(pool.isActive, "Pool not active");
        require(_amountIn > 0, "Amount in must be greater than 0");
        require(
            _tokenIn == pool.carbonTokenAddress || _tokenIn == pool.pairingTokenAddress,
            "Invalid token"
        );

        // Calculate fee
        uint256 fee = (_amountIn * feePercentage) / PRECISION;
        uint256 amountInAfterFee = _amountIn - fee;

        uint256 amountOut;

        if (_tokenIn == pool.carbonTokenAddress) {
            // Swap carbon token for pairing token
            uint256 k = pool.carbonTokenReserve * pool.pairingTokenReserve;
            uint256 newCarbonReserve = pool.carbonTokenReserve + amountInAfterFee;
            uint256 newPairingReserve = k / newCarbonReserve;
            amountOut = pool.pairingTokenReserve - newPairingReserve;

            pool.carbonTokenReserve = newCarbonReserve;
            pool.pairingTokenReserve = newPairingReserve;
        } else {
            // Swap pairing token for carbon token
            uint256 k = pool.carbonTokenReserve * pool.pairingTokenReserve;
            uint256 newPairingReserve = pool.pairingTokenReserve + amountInAfterFee;
            uint256 newCarbonReserve = k / newPairingReserve;
            amountOut = pool.carbonTokenReserve - newCarbonReserve;

            pool.carbonTokenReserve = newCarbonReserve;
            pool.pairingTokenReserve = newPairingReserve;
        }

        uint256 tradeId = tradeCounter++;
        poolTrades[_poolId].push(tradeId);

        emit SwapExecuted(
            tradeId,
            _poolId,
            msg.sender,
            _tokenIn,
            _tokenIn == pool.carbonTokenAddress ? pool.pairingTokenAddress : pool.carbonTokenAddress,
            _amountIn,
            amountOut,
            fee,
            block.timestamp
        );

        return amountOut;
    }

    // Calculate output amount for a given input
    function getAmountOut(
        uint256 _poolId,
        address _tokenIn,
        uint256 _amountIn
    ) external view poolExists(_poolId) returns (uint256) {
        LiquidityPool storage pool = liquidityPools[_poolId];

        uint256 fee = (_amountIn * feePercentage) / PRECISION;
        uint256 amountInAfterFee = _amountIn - fee;

        if (_tokenIn == pool.carbonTokenAddress) {
            uint256 k = pool.carbonTokenReserve * pool.pairingTokenReserve;
            uint256 newCarbonReserve = pool.carbonTokenReserve + amountInAfterFee;
            uint256 newPairingReserve = k / newCarbonReserve;
            return pool.pairingTokenReserve - newPairingReserve;
        } else {
            uint256 k = pool.carbonTokenReserve * pool.pairingTokenReserve;
            uint256 newPairingReserve = pool.pairingTokenReserve + amountInAfterFee;
            uint256 newCarbonReserve = k / newPairingReserve;
            return pool.carbonTokenReserve - newCarbonReserve;
        }
    }

    // Query functions
    function getPool(uint256 _poolId)
        external
        view
        poolExists(_poolId)
        returns (LiquidityPool memory)
    {
        return liquidityPools[_poolId];
    }

    function getLPTokenBalance(uint256 _poolId, address _holder)
        external
        view
        returns (uint256)
    {
        return lpTokenBalances[_poolId][_holder];
    }

    function getPoolTrades(uint256 _poolId)
        external
        view
        returns (uint256[] memory)
    {
        return poolTrades[_poolId];
    }

    // Helper function to calculate square root
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
