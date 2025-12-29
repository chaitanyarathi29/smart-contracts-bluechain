// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AerisIntegrationInterface
 * @dev Complete API reference for integrating with Aeris ecosystem
 * Shows all function signatures and usage patterns
 */

// ==================== STEP 1: PROJECT REGISTRY API ====================

interface IProjectRegistry {
    
    // ==== Admin Functions ====
    function whitelistGenerator(address _generator) external;
    function removeGeneratorFromWhitelist(address _generator) external;
    function whitelistVerifier(address _verifier) external;
    function removeVerifierFromWhitelist(address _verifier) external;
    
    // ==== Generator Functions ====
    /**
     * Register a new carbon credit generation project
     * @param _generatorName Name of the organization (NGO, trust, etc)
     * @param _projectName Name of the project (e.g., "Amazon Restoration")
     * @param _location Geographic location
     * @param _landArea Size of restored land in hectares
     * @param _identityDocHash IPFS hash of identity documents
     * @param _projectDetailsHash IPFS hash of project details PDF
     * @param _landInfoHash IPFS hash of land survey/info
     * @return projectId Unique project identifier
     */
    function registerProject(
        string memory _generatorName,
        string memory _projectName,
        string memory _location,
        uint256 _landArea,
        string memory _identityDocHash,
        string memory _projectDetailsHash,
        string memory _landInfoHash
    ) external returns (uint256);
    
    // ==== Verifier Functions ====
    /**
     * Register as a verifier
     * @param _verifierName Name of verification entity
     * @return verifierId Unique verifier identifier
     */
    function registerVerifier(string memory _verifierName)
        external
        returns (uint256);
    
    /**
     * Submit MRV (Measurement, Reporting, Verification) data
     * @param _projectId Project being verified
     * @param _satelliteImageryHash IPFS hash of satellite imagery
     * @param _fieldDataHash IPFS hash of ground-truth field data
     * @return mrvId Unique MRV submission identifier
     */
    function submitMRVData(
        uint256 _projectId,
        string memory _satelliteImageryHash,
        string memory _fieldDataHash
    ) external returns (uint256);
    
    // ==== Query Functions ====
    function getProject(uint256 _projectId) external view returns (
        uint256 projectId,
        address generatorAddress,
        string memory generatorName,
        string memory projectName,
        string memory location,
        uint256 landArea,
        string memory identityDocHash,
        string memory projectDetailsHash,
        string memory landInfoHash,
        uint256 registrationTimestamp,
        bool isActive
    );
    
    function getVerifier(uint256 _verifierId) external view returns (
        uint256 verifierId,
        address verifierAddress,
        string memory name,
        uint256 registrationTimestamp,
        bool isActive
    );
    
    function getMRVData(uint256 _mrvId) external view returns (
        uint256 mrvId,
        uint256 projectId,
        string memory satelliteImageryHash,
        string memory fieldDataHash,
        uint256 submissionTimestamp,
        bool isProcessed
    );
}

//STEP2:MRV VERIFICATIONAPI

interface IMRVVerification {
    
    // ==== Admin Functions ====
    /**
     * Register ML model for verification pipeline
     * @param _modelHash Hash/fingerprint of ML model
     * @param _modelName Name (e.g., "Stage 1: Aerial Segmentation")
     * @param _modelVersion Version string
     */
    function registerMLModel(
        bytes32 _modelHash,
        string memory _modelName,
        string memory _modelVersion
    ) external;
    
    function setRequiredApprovals(uint256 _requiredApprovals) external;
    function setToleranceThreshold(uint256 _toleranceThreshold) external;
    
    // ==== Block Generator Functions ====
    /**
     * Propose MRV block with computed carbon credits
     * Calls ML pipeline (Stage 1-4) offline and submits results
     * @param _mrvId MRV data submission being processed
     * @param _projectId Project ID
     * @param _mlModelHash Hash of the registered ML model used
     * @param _inputDataHash Hash of input data fed to model
     * @param _outputDataHash Hash of model output results
     * @param _carbonsCreditsGenerated CO2 equivalent in kg
     * @return blockId Unique block identifier
     */
    function proposeMRVBlock(
        uint256 _mrvId,
        uint256 _projectId,
        bytes32 _mlModelHash,
        bytes32 _inputDataHash,
        bytes32 _outputDataHash,
        uint256 _carbonsCreditsGenerated
    ) external returns (uint256);
    
    // ==== Validator Functions ====
    /**
     * Submit validator approval for MRV block
     * Validator independently runs same ML model and compares output
     * @param _blockId Block to validate
     * @param _computedOutputHash Hash of independently computed output
     * @param _approved Whether output matches within tolerance
     */
    function submitValidatorApproval(
        uint256 _blockId,
        bytes32 _computedOutputHash,
        bool _approved
    ) external;
    
    // ==== Admin Functions ====
    /**
     * Reject MRV block and slash validators
     * Called when block doesn't meet protocol requirements
     * @param _blockId Block to reject
     * @param _validatorIdsToSlash Validators to penalize (32 ETH lost)
     */
    function rejectMRVBlock(
        uint256 _blockId,
        uint256[] calldata _validatorIdsToSlash
    ) external;
    
    // ==== Query Functions ====
    function getMRVBlock(uint256 _blockId) external view returns (
        uint256 blockId,
        uint256 mrvId,
        uint256 projectId,
        bytes32 mlModelHash,
        bytes32 inputDataHash,
        bytes32 outputDataHash,
        uint256 carbonsCreditsGenerated,
        uint256 proposalTimestamp,
        bool isVerified,
        uint256 verificationTimestamp,
        uint256 approvalCount,
        address proposedBy
    );
    
    function getValidatorApproval(uint256 _blockId, uint256 _validatorId)
        external
        view
        returns (
            uint256 validatorId,
            address validatorAddress,
            bool approved,
            bytes32 computedOutputHash,
            uint256 approvalTimestamp
        );
    
    function getBlockApprovers(uint256 _blockId)
        external
        view
        returns (uint256[] memory);
}

//STEP3:CARBONTOKENAPI

interface ICarbonToken {
    
    // ==== Admin Functions ====
    function setVerificationContract(address _verificationContract) external;
    function setCarbonRetirementContract(address _carbonRetirementContract) external;
    
    // ==== Verification-only Functions ====
    /**
     * Mint carbon tokens after verified block
     * Only called by MRVVerification contract after consensus
     * @param _to Generator receiving tokens
     * @param _amount CO2 equivalent in kg (token amount)
     * @param _projectId Source project
     * @return tokenId Unique token identifier
     */
    function mint(
        address _to,
        uint256 _amount,
        uint256 _projectId
    ) external returns (uint256);
    
    // ==== Retirement-only Functions ====
    /**
     * Burn carbon tokens when industry offsets emissions
     * Only called by CarbonRetirement contract
     * @param _from Address burning tokens
     * @param _amount Amount to burn
     * @param _tokenId Token identifier
     */
    function burn(
        address _from,
        uint256 _amount,
        uint256 _tokenId
    ) external;
    
    //StandardERC20Functions 
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value)
        external
        returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    
    //Query Functions
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    
    function getTokenMetadata(uint256 _tokenId) external view returns (
        uint256 tokenId,
        uint256 projectId,
        uint256 amount,
        uint256 mintTimestamp,
        bool isRetired,
        uint256 retirementTimestamp
    );
}

//STEP4:VALIDATORSTAKINGAPI

interface IValidatorStaking {
    
    //AdminFunctions
    function setVerificationContract(address _verificationContract) external;
    function deactivateValidator(uint256 _validatorId) external;
    
    // ValidatorFunctions
    /**
     * Register as validator by staking 32 ETH
     * Grants cryptographic certificate for validation rights
     * @return validatorId Unique validator identifier
     * 
     * Example:
     * await validatorStaking.registerValidator({value: ethers.utils.parseEther("32")})
     */
    function registerValidator() external payable returns (uint256);
    
    /**
     * Withdraw staked amount after deactivation
     * Only possible if certificate not slashed
     * @param _validatorId Validator to withdraw for
     */
    function withdrawStake(uint256 _validatorId) external;
    
    //Verification-onlyFunctions
    /**
     * Slash validator certificate (called by MRVVerification)
     * Penalizes incorrect block approvals
     * @param _validatorId Validator to slash
     */
    function slashValidator(uint256 _validatorId) external;
    
    //QueryFunctions
    function getValidator(uint256 _validatorId) external view returns (
        uint256 validatorId,
        address validatorAddress,
        uint256 stakedAmount,
        uint256 certificateValue,
        bool isActive,
        uint256 registrationTimestamp,
        uint256 slashedAmount,
        bool certificateSlashed
    );
    
    function getCertificate(uint256 _certificateId) external view returns (
        uint256 certificateId,
        uint256 validatorId,
        address validatorAddress,
        uint256 amount,
        uint256 issuedTimestamp,
        bool isValid,
        uint256 slashTimestamp
    );
    
    function isValidatorActive(uint256 _validatorId)
        external
        view
        returns (bool);
    
    function getValidatorIdByAddress(address _validator)
        external
        view
        returns (uint256);
    
    function getValidatorCertificates(uint256 _validatorId)
        external
        view
        returns (uint256[] memory);
}

//STEP 5:PERMISSIONED AMM API 

interface IPermissionedAMM {
    
    // ==== Admin Functions ====
    function whitelistToken(address _token) external;
    function removeTokenFromWhitelist(address _token) external;
    function approveGenerator(address _generator) external;
    function removeGeneratorFromApproved(address _generator) external;
    function setFeePercentage(uint256 _feePercentage) external;
    
    // ==== Generator Functions ====
    /**
     * Create liquidity pool for trading carbon tokens
     * @param _pairingTokenAddress Token to pair with carbon tokens (USDC, DAI, etc)
     * @param _initialCarbonAmount Initial carbon token reserve
     * @param _initialPairingAmount Initial pairing token reserve
     * @return poolId Unique pool identifier
     */
    function createLiquidityPool(
        address _pairingTokenAddress,
        uint256 _initialCarbonAmount,
        uint256 _initialPairingAmount
    ) external returns (uint256);
    
    /**
     * Add liquidity to existing pool
     * @param _poolId Pool to add to
     * @param _carbonAmount Carbon tokens to add
     * @param _pairingAmount Pairing tokens to add
     * @return lpTokens LP tokens received
     */
    function addLiquidity(
        uint256 _poolId,
        uint256 _carbonAmount,
        uint256 _pairingAmount
    ) external returns (uint256);
    
    /**
     * Remove liquidity from pool
     * @param _poolId Pool to remove from
     * @param _lpTokenAmount LP tokens to burn
     * @return carbonAmount Carbon tokens received
     * @return pairingAmount Pairing tokens received
     */
    function removeLiquidity(
        uint256 _poolId,
        uint256 _lpTokenAmount
    ) external returns (uint256, uint256);
    
    // ==== Trader Functions (Industries) ====
    /**
     * Swap tokens via constant product formula
     * price = (pairingReserve / carbonReserve)
     * @param _poolId Pool to trade on
     * @param _tokenIn Token being swapped in
     * @param _amountIn Amount of token in
     * @return amountOut Amount of token received
     * 
     * Example: Industry buys carbon tokens with USDC
     * await permissionedAMM.swap(poolId, USDC_ADDRESS, ethers.utils.parseUnits("50000", 6))
     */
    function swap(
        uint256 _poolId,
        address _tokenIn,
        uint256 _amountIn
    ) external returns (uint256);
    
    // ==== Query Functions ====
    /**
     * Get expected output amount before swap
     * @param _poolId Pool to trade on
     * @param _tokenIn Token being swapped in
     * @param _amountIn Amount of token in
     * @return amountOut Expected output amount
     */
    function getAmountOut(
        uint256 _poolId,
        address _tokenIn,
        uint256 _amountIn
    ) external view returns (uint256);
    
    function getPool(uint256 _poolId) external view returns (
        uint256 poolId,
        address creator,
        address carbonTokenAddress,
        address pairingTokenAddress,
        uint256 carbonTokenReserve,
        uint256 pairingTokenReserve,
        uint256 lpTokenSupply,
        bool isActive,
        uint256 creationTimestamp
    );
    
    function getLPTokenBalance(uint256 _poolId, address _holder)
        external
        view
        returns (uint256);
    
    function getPoolTrades(uint256 _poolId)
        external
        view
        returns (uint256[] memory);
}

//STEP6:CARBON RETIREMENT API

interface ICarbonRetirement {
    
    //IndustryFunctions
    /**
     * Register as industry for emission offsetting
     * @param _industryName Name of company/organization
     * @return success Registration successful
     */
    function registerIndustry(string memory _industryName)
        external
        returns (bool);
    
    /**
     * Offset emissions by burning carbon tokens
     * Records permanent offset, prevents double-counting
     * @param _tokenId Carbon token to retire
     * @param _carbonAmount Amount to offset (kg CO2)
     * @param _retirementReason Reason for offset (optional)
     * @return retirementId Unique retirement record ID
     * 
     * Example: PowerCorp retires 5000 kg CO2 for Q1 operations
     * await carbonRetirement.offsetCarbonEmissions(
     *     tokenId,
     *     5000,
     *     "Q1 2024 emissions offset"
     * )
     */
    function offsetCarbonEmissions(
        uint256 _tokenId,
        uint256 _carbonAmount,
        string memory _retirementReason
    ) external returns (uint256);
    
    //AdminFunctions
    /**
     * Record token retirement for audit/cleanup
     * @param _tokenId Token to retire
     * @param _carbonAmount Amount (kg CO2)
     * @param _reason Reason for retirement
     * @return retirementId Unique retirement record ID
     */
    function recordTokenRetirement(
        uint256 _tokenId,
        uint256 _carbonAmount,
        string memory _reason
    ) external returns (uint256);
    
    /**
     * Expire annual offset credits at end of financial year
     * Credits valid for one calendar/financial year only
     * @param _industry Industry address
     * @param _year Financial year to expire
     * @return expiredAmount Total amount expired
     */
    function expireAnnualOffset(address _industry, uint256 _year)
        external
        returns (uint256);
    
    /**
     * Audit industry offsets and verify compliance
     * @param _industry Industry address
     * @param _year Financial year to audit
     * @return totalOffsetAmount Total offset in year
     * @return canCarryForward Can credits carry to next year
     */
    function auditIndustryOffsets(address _industry, uint256 _year)
        external
        view
        returns (uint256, bool);
    
    //QueryFunctions
    function getRetirementRecord(uint256 _retirementId) external view returns (
        uint256 retirementId,
        address offsetter,
        uint256 tokenId,
        uint256 carbonAmount,
        string memory retirementReason,
        uint256 retirementTimestamp,
        uint256 financialYear,
        bool isPermanent
    );
    
    function getIndustryAccount(address _industry) external view returns (
        address industryAddress,
        string memory industryName,
        uint256 totalCarbonBurned,
        uint256[] memory retirementRecords,
        bool isRegistered,
        uint256 registrationTimestamp
    );
    
    function getIndustryRetirements(address _industry)
        external
        view
        returns (uint256[] memory);
    
    function getAnnualOffset(address _industry, uint256 _year)
        external
        view
        returns (
            uint256 year,
            address industry,
            uint256 totalOffsetAmount,
            uint256 offsetCount
        );
    
    function isTokenBurned(uint256 _tokenId) external view returns (bool);
    function getTotalCarbonBurnedByIndustry(address _industry)
        external
        view
        returns (uint256);
    
    function getCurrentFinancialYear() external view returns (uint256);
}

//USAGE PATTERNS

/**
 * COMPLETE FLOW EXAMPLE:
 * 
 * 1. REGISTRATION
 *    - Admin whitelists NGO and Verifiers
 *    - NGO calls registerProject() in ProjectRegistry
 *    - Verifier calls registerVerifier() in ProjectRegistry
 * 
 * 2. MRV SUBMISSION
 *    - Verifier calls submitMRVData() with IPFS hashes
 *    - Off-chain: 4-stage ML pipeline processes data
 * 
 * 3. VERIFICATION
 *    - Block generator calls proposeMRVBlock() with results
 *    - Validators independently verify and call submitValidatorApproval()
 *    - Auto-triggers token minting when consensus reached
 * 
 * 4. TRADING
 *    - NGO calls createLiquidityPool() with initial reserves
 *    - Industry calls swap() to buy carbon tokens
 *    - Price determined by constant product formula
 * 
 * 5. OFFSET & RETIREMENT
 *    - Industry calls registerIndustry()
 *    - Industry calls offsetCarbonEmissions() to burn tokens
 *    - Offset recorded immutably on-chain
 *    - At year-end, tokens expire or carry forward
 */
