// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ProjectRegistry.sol";
import "./CarbonToken.sol";
import "./ValidatorStaking.sol";

/**
 * @title MRVVerification
 * @dev Handles MRV data verification with stake-based consensus mechanism
 */
contract MRVVerification {
    // Structs
    struct MRVBlock {
        uint256 blockId;
        uint256 mrvId;
        uint256 projectId;
        bytes32 mlModelHash; // Hash of registered ML model
        bytes32 inputDataHash; // Hash of MRV input data
        bytes32 outputDataHash; // Hash of computed output
        uint256 carbonCreditsGenerated; // CO2 equivalent in kg
        uint256 proposalTimestamp;
        bool isVerified;
        uint256 verificationTimestamp;
        uint256 approvalCount;
        address proposedBy;
    }

    struct ValidatorApproval {
        uint256 validatorId;
        address validatorAddress;
        bool approved;
        bytes32 computedOutputHash;
        uint256 approvalTimestamp;
    }

    struct MLModel {
        bytes32 modelHash;
        string modelName;
        string modelVersion;
        bool isActive;
        uint256 registrationTimestamp;
    }

    // State variables
    mapping(uint256 => MRVBlock) public mrvBlocks;
    mapping(uint256 => mapping(uint256 => ValidatorApproval)) public blockValidatorApprovals;
    mapping(uint256 => uint256[]) public blockApprovers;
    mapping(bytes32 => MLModel) public registeredModels;

    uint256 public blockCounter = 0;
    uint256 public modelCounter = 0;
    uint256 public requiredApprovals = 2; // Minimum validators needed for consensus
    uint256 public toleranceThreshold = 5; // 5% tolerance for output matching

    address public projectRegistry;
    address public carbonToken;
    address public validatorStaking;
    address public admin;

    // Events
    event MRVBlockProposed(
        uint256 indexed blockId,
        uint256 indexed mrvId,
        uint256 indexed projectId,
        address proposedBy,
        uint256 timestamp
    );

    event ValidatorApprovalSubmitted(
        uint256 indexed blockId,
        uint256 indexed validatorId,
        address indexed validator,
        bool approved,
        uint256 timestamp
    );

    event MRVBlockVerified(
        uint256 indexed blockId,
        uint256 indexed mrvId,
        uint256 carbonsCreditsGenerated,
        uint256 timestamp
    );

    event MRVBlockRejected(
        uint256 indexed blockId,
        uint256 indexed validatorId,
        uint256 timestamp
    );

    event MLModelRegistered(
        bytes32 indexed modelHash,
        string modelName,
        string modelVersion,
        uint256 timestamp
    );

    event ValidatorSlashed(
        uint256 indexed blockId,
        uint256 indexed validatorId,
        address indexed validator,
        uint256 timestamp
    );

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyValidator() {
        require(
            ValidatorStaking(validatorStaking).isValidatorActive(
                ValidatorStaking(validatorStaking).getValidatorIdByAddress(msg.sender)
            ),
            "Only active validators can call this"
        );
        _;
    }

    // Constructor
    constructor(
        address _projectRegistry,
        address _carbonToken,
        address _validatorStaking
    ) {
        projectRegistry = _projectRegistry;
        carbonToken = _carbonToken;
        validatorStaking = _validatorStaking;
        admin = msg.sender;
    }

    // Register ML Model
    function registerMLModel(
        bytes32 _modelHash,
        string memory _modelName,
        string memory _modelVersion
    ) external onlyAdmin {
        require(registeredModels[_modelHash].registrationTimestamp == 0, "Model already registered");

        registeredModels[_modelHash] = MLModel({
            modelHash: _modelHash,
            modelName: _modelName,
            modelVersion: _modelVersion,
            isActive: true,
            registrationTimestamp: block.timestamp
        });

        emit MLModelRegistered(_modelHash, _modelName, _modelVersion, block.timestamp);
    }

    // Propose MRV Block
    function proposeMRVBlock(
        uint256 _mrvId,
        uint256 _projectId,
        bytes32 _mlModelHash,
        bytes32 _inputDataHash,
        bytes32 _outputDataHash,
        uint256 _carbonsCreditsGenerated
    ) external returns (uint256) {
        require(registeredModels[_mlModelHash].isActive, "Model not registered or inactive");

        uint256 blockId = blockCounter++;

        mrvBlocks[blockId] = MRVBlock({
            blockId: blockId,
            mrvId: _mrvId,
            projectId: _projectId,
            mlModelHash: _mlModelHash,
            inputDataHash: _inputDataHash,
            outputDataHash: _outputDataHash,
            carbonsCreditsGenerated: _carbonsCreditsGenerated,
            proposalTimestamp: block.timestamp,
            isVerified: false,
            verificationTimestamp: 0,
            approvalCount: 0,
            proposedBy: msg.sender
        });

        emit MRVBlockProposed(blockId, _mrvId, _projectId, msg.sender, block.timestamp);
        return blockId;
    }

    // Submit validator approval
    function submitValidatorApproval(
        uint256 _blockId,
        bytes32 _computedOutputHash,
        bool _approved
    ) external onlyValidator {
        MRVBlock storage block_ = mrvBlocks[_blockId];
        require(!block_.isVerified, "Block already verified");

        uint256 validatorId = ValidatorStaking(validatorStaking).getValidatorIdByAddress(msg.sender);

        // Check if output matches within tolerance
        bool outputMatches = _computedOutputHash == block_.outputDataHash;

        blockValidatorApprovals[_blockId][validatorId] = ValidatorApproval({
            validatorId: validatorId,
            validatorAddress: msg.sender,
            approved: _approved && outputMatches,
            computedOutputHash: _computedOutputHash,
            approvalTimestamp: block.timestamp
        });

        if (_approved && outputMatches) {
            block_.approvalCount++;
            blockApprovers[_blockId].push(validatorId);
        }

        // Check if we have enough approvals for consensus
        if (block_.approvalCount >= requiredApprovals) {
            verifyMRVBlock(_blockId);
        }

        emit ValidatorApprovalSubmitted(_blockId, validatorId, msg.sender, _approved && outputMatches, block.timestamp);
    }

    // Internal function to verify MRV block
    function verifyMRVBlock(uint256 _blockId) internal {
        MRVBlock storage block_ = mrvBlocks[_blockId];
        require(!block_.isVerified, "Block already verified");
        require(block_.approvalCount >= requiredApprovals, "Not enough approvals");

        block_.isVerified = true;
        block_.verificationTimestamp = block.timestamp;

        // Mint carbon tokens
        CarbonToken(carbonToken).mint(
            block_.proposedBy,
            block_.carbonsCreditsGenerated,
            block_.projectId
        );

        emit MRVBlockVerified(_blockId, block_.mrvId, block_.carbonsCreditsGenerated, block.timestamp);
    }

    // Reject MRV block and slash validators
    function rejectMRVBlock(uint256 _blockId, uint256[] calldata _validatorIdsToSlash)
        external
        onlyAdmin
    {
        MRVBlock storage block_ = mrvBlocks[_blockId];
        require(!block_.isVerified, "Block already verified");

        // Slash validators who approved incorrect data
        for (uint256 i = 0; i < _validatorIdsToSlash.length; i++) {
            ValidatorStaking(validatorStaking).slashValidator(_validatorIdsToSlash[i]);
            emit ValidatorSlashed(
                _blockId,
                _validatorIdsToSlash[i],
                blockValidatorApprovals[_blockId][_validatorIdsToSlash[i]].validatorAddress,
                block.timestamp
            );
        }

        emit MRVBlockRejected(_blockId, _validatorIdsToSlash[0], block.timestamp);
    }

    // Set required approvals threshold
    function setRequiredApprovals(uint256 _requiredApprovals) external onlyAdmin {
        require(_requiredApprovals > 0, "Required approvals must be greater than 0");
        requiredApprovals = _requiredApprovals;
    }

    // Set tolerance threshold
    function setToleranceThreshold(uint256 _toleranceThreshold) external onlyAdmin {
        toleranceThreshold = _toleranceThreshold;
    }

    // Query functions
    function getMRVBlock(uint256 _blockId)
        external
        view
        returns (MRVBlock memory)
    {
        return mrvBlocks[_blockId];
    }

    function getValidatorApproval(uint256 _blockId, uint256 _validatorId)
        external
        view
        returns (ValidatorApproval memory)
    {
        return blockValidatorApprovals[_blockId][_validatorId];
    }

    function getBlockApprovers(uint256 _blockId)
        external
        view
        returns (uint256[] memory)
    {
        return blockApprovers[_blockId];
    }

    function getMLModel(bytes32 _modelHash)
        external
        view
        returns (MLModel memory)
    {
        return registeredModels[_modelHash];
    }
}
