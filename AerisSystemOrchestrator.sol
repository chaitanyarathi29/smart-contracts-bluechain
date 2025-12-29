// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AerisSystemOrchestrator
 * @dev Orchestrates the entire Aeris ecosystem - handles contract initialization and integration
 */
contract AerisSystemOrchestrator {
    // Contract addresses
    address public projectRegistry;
    address public mrvVerification;
    address public carbonToken;
    address public validatorStaking;
    address public permissionedAMM;
    address public carbonRetirement;
    address public admin;

    // System status
    enum SystemStatus {
        UNINITIALIZED,
        PARTIALLY_INITIALIZED,
        FULLY_INITIALIZED,
        HALTED
    }

    SystemStatus public currentStatus = SystemStatus.UNINITIALIZED;

    // Initialization tracking
    struct DeploymentPhase {
        bool coreContractsDeployed;
        bool verificationLayerDeployed;
        bool tradingAndRetirementDeployed;
        bool addressesLinked;
        bool systemReady;
    }

    DeploymentPhase public deploymentPhase;

    // Events
    event CoreContractsDeployed(
        address indexed projectRegistry,
        address indexed carbonToken,
        address indexed validatorStaking
    );

    event VerificationLayerDeployed(
        address indexed mrvVerification
    );

    event TradingAndRetirementDeployed(
        address indexed permissionedAMM,
        address indexed carbonRetirement
    );

    event ContractAddressesLinked();

    event SystemStatusChanged(SystemStatus newStatus);

    event MLModelRegistered(
        bytes32 indexed modelHash,
        string modelName
    );

    event GeneratorWhitelisted(address indexed generator);
    event VerifierWhitelisted(address indexed verifier);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this");
        _;
    }

    modifier systemInitialized() {
        require(currentStatus == SystemStatus.FULLY_INITIALIZED, "System not fully initialized");
        _;
    }

    // Constructor
    constructor() {
        admin = msg.sender;
    }

    // ==================== DEPLOYMENT PHASE 1: CORE CONTRACTS ====================
    
    /**
     * Phase 1: Deploy core contracts
     * Must be called first
     */
    function initializeCoreContracts(
        address _projectRegistry,
        address _carbonToken,
        address _validatorStaking
    ) external onlyAdmin {
        require(currentStatus == SystemStatus.UNINITIALIZED, "Already initialized");
        require(_projectRegistry != address(0), "Invalid projectRegistry");
        require(_carbonToken != address(0), "Invalid carbonToken");
        require(_validatorStaking != address(0), "Invalid validatorStaking");

        projectRegistry = _projectRegistry;
        carbonToken = _carbonToken;
        validatorStaking = _validatorStaking;

        deploymentPhase.coreContractsDeployed = true;
        currentStatus = SystemStatus.PARTIALLY_INITIALIZED;

        emit CoreContractsDeployed(_projectRegistry, _carbonToken, _validatorStaking);
    }

    // ==================== DEPLOYMENT PHASE 2: VERIFICATION LAYER ====================

    /**
     * Phase 2: Deploy verification contract
     * Must be called after Phase 1
     */
    function initializeVerificationLayer(
        address _mrvVerification
    ) external onlyAdmin {
        require(deploymentPhase.coreContractsDeployed, "Core contracts not deployed");
        require(_mrvVerification != address(0), "Invalid mrvVerification");

        mrvVerification = _mrvVerification;
        deploymentPhase.verificationLayerDeployed = true;

        emit VerificationLayerDeployed(_mrvVerification);
    }

    // ==================== DEPLOYMENT PHASE 3: TRADING & RETIREMENT ====================

    /**
     * Phase 3: Deploy trading and retirement contracts
     * Must be called after Phase 2
     */
    function initializeTradingAndRetirement(
        address _permissionedAMM,
        address _carbonRetirement
    ) external onlyAdmin {
        require(deploymentPhase.verificationLayerDeployed, "Verification layer not deployed");
        require(_permissionedAMM != address(0), "Invalid permissionedAMM");
        require(_carbonRetirement != address(0), "Invalid carbonRetirement");

        permissionedAMM = _permissionedAMM;
        carbonRetirement = _carbonRetirement;

        deploymentPhase.tradingAndRetirementDeployed = true;

        emit TradingAndRetirementDeployed(_permissionedAMM, _carbonRetirement);
    }

    // ==================== INITIALIZATION & LINKING ====================

    /**
     * Link all contract addresses together
     * Call after all contracts are deployed
     */
    function linkAllContracts() external onlyAdmin {
        require(deploymentPhase.tradingAndRetirementDeployed, "Not all contracts deployed");
        require(!deploymentPhase.addressesLinked, "Already linked");

        // CarbonToken needs to know about Verification and Retirement
        // (These would need setter functions in those contracts)
        // Example: CarbonToken(carbonToken).setVerificationContract(mrvVerification);
        
        // ValidatorStaking needs to know about Verification
        // Example: ValidatorStaking(validatorStaking).setVerificationContract(mrvVerification);

        deploymentPhase.addressesLinked = true;
        currentStatus = SystemStatus.FULLY_INITIALIZED;

        emit ContractAddressesLinked();
        emit SystemStatusChanged(SystemStatus.FULLY_INITIALIZED);
    }

    // ==================== ML MODEL REGISTRATION ====================

    /**
     * Register ML models to be used in verification
     * Stage 1: Aerial Semantic Segmentation
     * Stage 2: Multispectral Biomass Analysis (NDVI)
     * Stage 3: Incremental Biomass Growth Prediction
     * Stage 4: Biomass to CO2 Conversion
     */
    function registerMLModel(
        bytes32 _modelHash,
        string memory _modelName,
        string memory _modelVersion
    ) external onlyAdmin systemInitialized {
        // Call MRVVerification contract
        // MRVVerification(mrvVerification).registerMLModel(_modelHash, _modelName, _modelVersion);

        emit MLModelRegistered(_modelHash, _modelName);
    }

    // ==================== ENTITY WHITELISTING ====================

    /**
     * Whitelist generators (NGOs, environmental groups, charitable trusts)
     */
    function whitelistGenerator(address _generator)
        external
        onlyAdmin
        systemInitialized
    {
        require(_generator != address(0), "Invalid generator address");
        
        // Call ProjectRegistry contract
        // ProjectRegistry(projectRegistry).whitelistGenerator(_generator);

        emit GeneratorWhitelisted(_generator);
    }

    /**
     * Whitelist verifiers (environmental validators)
     */
    function whitelistVerifier(address _verifier)
        external
        onlyAdmin
        systemInitialized
    {
        require(_verifier != address(0), "Invalid verifier address");
        
        // Call ProjectRegistry contract
        // ProjectRegistry(projectRegistry).whitelistVerifier(_verifier);

        emit VerifierWhitelisted(_verifier);
    }

    // ==================== SYSTEM CONFIGURATION ====================

    /**
     * Configure verification parameters
     */
    function configureVerificationParameters(
        uint256 _requiredApprovals,
        uint256 _toleranceThreshold
    ) external onlyAdmin systemInitialized {
        // MRVVerification(mrvVerification).setRequiredApprovals(_requiredApprovals);
        // MRVVerification(mrvVerification).setToleranceThreshold(_toleranceThreshold);
    }

    /**
     * Configure AMM parameters
     */
    function configureAMMParameters(
        address _pairingToken,
        uint256 _feePercentage
    ) external onlyAdmin systemInitialized {
        // PermissionedAMM(permissionedAMM).whitelistToken(_pairingToken);
        // PermissionedAMM(permissionedAMM).setFeePercentage(_feePercentage);
    }

    // ==================== SYSTEM STATUS & GETTERS ====================

    /**
     * Get current initialization status
     */
    function getSystemStatus()
        external
        view
        returns (string memory)
    {
        if (currentStatus == SystemStatus.UNINITIALIZED) {
            return "Uninitialized - Deploy Phase 1";
        } else if (currentStatus == SystemStatus.PARTIALLY_INITIALIZED) {
            return "Partially Initialized - Continue with Phase 2 & 3";
        } else if (currentStatus == SystemStatus.FULLY_INITIALIZED) {
            return "Fully Initialized and Ready";
        } else {
            return "System Halted";
        }
    }

    /**
     * Get deployment progress
     */
    function getDeploymentProgress()
        external
        view
        returns (
            bool coreDeployed,
            bool verificationDeployed,
            bool tradingDeployed,
            bool addressesLinked,
            bool ready
        )
    {
        return (
            deploymentPhase.coreContractsDeployed,
            deploymentPhase.verificationLayerDeployed,
            deploymentPhase.tradingAndRetirementDeployed,
            deploymentPhase.addressesLinked,
            deploymentPhase.systemReady
        );
    }

    /**
     * Get all contract addresses
     */
    function getAllContractAddresses()
        external
        view
        systemInitialized
        returns (
            address registry,
            address verification,
            address token,
            address validators,
            address amm,
            address retirement
        )
    {
        return (
            projectRegistry,
            mrvVerification,
            carbonToken,
            validatorStaking,
            permissionedAMM,
            carbonRetirement
        );
    }
}
