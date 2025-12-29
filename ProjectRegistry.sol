// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ProjectRegistry
 * @dev Manages registration and identity of generators and projects
 */
contract ProjectRegistry {
    // Structs
    struct Project {
        uint256 projectId;
        address generatorAddress;
        string generatorName;
        string projectName;
        string location;
        uint256 landArea; // in hectares
        string identityDocHash; // IPFS hash
        string projectDetailsHash; // IPFS hash
        string landInfoHash; // IPFS hash
        uint256 registrationTimestamp;
        bool isActive;
    }

    struct Verifier {
        uint256 verifierId;
        address verifierAddress;
        string name;
        uint256 registrationTimestamp;
        bool isActive;
    }

    struct MRVData {
        uint256 mrvId;
        uint256 projectId;
        string satelliteImageryHash; // IPFS hash
        string fieldDataHash; // IPFS hash
        uint256 submissionTimestamp;
        bool isProcessed;
    }

    // State variables
    mapping(uint256 => Project) public projects;
    mapping(uint256 => Verifier) public verifiers;
    mapping(uint256 => MRVData) public mrvDataRecords;
    mapping(address => bool) public whitelistedGenerators;
    mapping(address => bool) public whitelistedVerifiers;

    uint256 public projectCounter = 0;
    uint256 public verifierCounter = 0;
    uint256 public mrvCounter = 0;

    address public admin;

    // Events
    event ProjectRegistered(
        uint256 indexed projectId,
        address indexed generator,
        string projectName,
        uint256 timestamp
    );

    event VerifierRegistered(
        uint256 indexed verifierId,
        address indexed verifier,
        string name,
        uint256 timestamp
    );

    event MRVDataSubmitted(
        uint256 indexed mrvId,
        uint256 indexed projectId,
        string satelliteImageryHash,
        uint256 timestamp
    );

    event GeneratorWhitelisted(address indexed generator);
    event GeneratorRemovedFromWhitelist(address indexed generator);
    event VerifierWhitelisted(address indexed verifier);
    event VerifierRemovedFromWhitelist(address indexed verifier);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyWhitelistedGenerator() {
        require(whitelistedGenerators[msg.sender], "Generator not whitelisted");
        _;
    }

    modifier onlyWhitelistedVerifier() {
        require(whitelistedVerifiers[msg.sender], "Verifier not whitelisted");
        _;
    }

    // Constructor
    constructor() {
        admin = msg.sender;
    }

    // Admin functions
    function whitelistGenerator(address _generator) external onlyAdmin {
        whitelistedGenerators[_generator] = true;
        emit GeneratorWhitelisted(_generator);
    }

    function removeGeneratorFromWhitelist(address _generator) external onlyAdmin {
        whitelistedGenerators[_generator] = false;
        emit GeneratorRemovedFromWhitelist(_generator);
    }

    function whitelistVerifier(address _verifier) external onlyAdmin {
        whitelistedVerifiers[_verifier] = true;
        emit VerifierWhitelisted(_verifier);
    }

    function removeVerifierFromWhitelist(address _verifier) external onlyAdmin {
        whitelistedVerifiers[_verifier] = false;
        emit VerifierRemovedFromWhitelist(_verifier);
    }

    // Generator functions
    function registerProject(
        string memory _generatorName,
        string memory _projectName,
        string memory _location,
        uint256 _landArea,
        string memory _identityDocHash,
        string memory _projectDetailsHash,
        string memory _landInfoHash
    ) external onlyWhitelistedGenerator returns (uint256) {
        uint256 projectId = projectCounter++;

        projects[projectId] = Project({
            projectId: projectId,
            generatorAddress: msg.sender,
            generatorName: _generatorName,
            projectName: _projectName,
            location: _location,
            landArea: _landArea,
            identityDocHash: _identityDocHash,
            projectDetailsHash: _projectDetailsHash,
            landInfoHash: _landInfoHash,
            registrationTimestamp: block.timestamp,
            isActive: true
        });

        emit ProjectRegistered(projectId, msg.sender, _projectName, block.timestamp);
        return projectId;
    }

    // Verifier functions
    function registerVerifier(
        string memory _verifierName
    ) external onlyWhitelistedVerifier returns (uint256) {
        uint256 verifierId = verifierCounter++;

        verifiers[verifierId] = Verifier({
            verifierId: verifierId,
            verifierAddress: msg.sender,
            name: _verifierName,
            registrationTimestamp: block.timestamp,
            isActive: true
        });

        emit VerifierRegistered(verifierId, msg.sender, _verifierName, block.timestamp);
        return verifierId;
    }

    // MRV Data submission
    function submitMRVData(
        uint256 _projectId,
        string memory _satelliteImageryHash,
        string memory _fieldDataHash
    ) external onlyWhitelistedVerifier returns (uint256) {
        require(projects[_projectId].isActive, "Project not active");

        uint256 mrvId = mrvCounter++;

        mrvDataRecords[mrvId] = MRVData({
            mrvId: mrvId,
            projectId: _projectId,
            satelliteImageryHash: _satelliteImageryHash,
            fieldDataHash: _fieldDataHash,
            submissionTimestamp: block.timestamp,
            isProcessed: false
        });

        emit MRVDataSubmitted(mrvId, _projectId, _satelliteImageryHash, block.timestamp);
        return mrvId;
    }

    // Query functions
    function getProject(uint256 _projectId) external view returns (Project memory) {
        return projects[_projectId];
    }

    function getVerifier(uint256 _verifierId) external view returns (Verifier memory) {
        return verifiers[_verifierId];
    }

    function getMRVData(uint256 _mrvId) external view returns (MRVData memory) {
        return mrvDataRecords[_mrvId];
    }

    function markMRVDataProcessed(uint256 _mrvId) external onlyAdmin {
        require(mrvDataRecords[_mrvId].mrvId == _mrvId, "MRV data not found");
        mrvDataRecords[_mrvId].isProcessed = true;
    }
}
