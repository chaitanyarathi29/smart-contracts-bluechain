// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ValidatorStaking
 * @dev Manages validator registration, staking, and certificate issuance
 */
contract ValidatorStaking {
    uint256 public constant STAKE_AMOUNT = 32 ether;

    struct Validator {
        uint256 validatorId;
        address validatorAddress;
        uint256 stakedAmount;
        uint256 certificateValue; // 32 ETH in wei
        bool isActive;
        uint256 registrationTimestamp;
        uint256 slashedAmount;
        bool certificateSlashed;
    }

    struct ValidationCertificate {
        uint256 certificateId;
        uint256 validatorId;
        address validatorAddress;
        uint256 amount; // 32 ETH
        uint256 issuedTimestamp;
        bool isValid;
        uint256 slashTimestamp;
    }

    // State variables
    mapping(uint256 => Validator) public validators;
    mapping(uint256 => ValidationCertificate) public certificates;
    mapping(address => uint256) public validatorIdByAddress;
    mapping(uint256 => uint256[]) public validatorCertificates;

    uint256 public validatorCounter = 0;
    uint256 public certificateCounter = 0;
    uint256 public totalStakedAmount = 0;

    address public verificationContract;
    address public admin;

    // Events
    event ValidatorRegistered(
        uint256 indexed validatorId,
        address indexed validator,
        uint256 stakedAmount,
        uint256 timestamp
    );

    event CertificateIssued(
        uint256 indexed certificateId,
        uint256 indexed validatorId,
        address indexed validator,
        uint256 amount,
        uint256 timestamp
    );

    event CertificateSlashed(
        uint256 indexed certificateId,
        uint256 indexed validatorId,
        address indexed validator,
        uint256 slashedAmount,
        uint256 timestamp
    );

    event ValidatorDeactivated(uint256 indexed validatorId, address indexed validator);

    event ValidatorWithdrawn(
        uint256 indexed validatorId,
        address indexed validator,
        uint256 amount
    );

    // Modifiers
    modifier onlyVerification() {
        require(
            msg.sender == verificationContract,
            "Only verification contract can call this"
        );
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier validatorExists(uint256 _validatorId) {
        require(validators[_validatorId].validatorAddress != address(0), "Validator not found");
        _;
    }

    // Constructor
    constructor() {
        admin = msg.sender;
    }

    // Admin function
    function setVerificationContract(address _verificationContract) external onlyAdmin {
        verificationContract = _verificationContract;
    }

    // Validator registration
    function registerValidator() external payable returns (uint256) {
        require(msg.value == STAKE_AMOUNT, "Must stake exactly 32 ETH");
        require(validatorIdByAddress[msg.sender] == 0, "Validator already registered");

        uint256 validatorId = validatorCounter++;
        validatorIdByAddress[msg.sender] = validatorId;

        validators[validatorId] = Validator({
            validatorId: validatorId,
            validatorAddress: msg.sender,
            stakedAmount: msg.value,
            certificateValue: STAKE_AMOUNT,
            isActive: true,
            registrationTimestamp: block.timestamp,
            slashedAmount: 0,
            certificateSlashed: false
        });

        totalStakedAmount += msg.value;

        // Issue certificate
        uint256 certificateId = certificateCounter++;
        certificates[certificateId] = ValidationCertificate({
            certificateId: certificateId,
            validatorId: validatorId,
            validatorAddress: msg.sender,
            amount: STAKE_AMOUNT,
            issuedTimestamp: block.timestamp,
            isValid: true,
            slashTimestamp: 0
        });

        validatorCertificates[validatorId].push(certificateId);

        emit ValidatorRegistered(validatorId, msg.sender, msg.value, block.timestamp);
        emit CertificateIssued(certificateId, validatorId, msg.sender, STAKE_AMOUNT, block.timestamp);

        return validatorId;
    }

    // Slash validator certificate
    function slashValidator(uint256 _validatorId) external onlyVerification validatorExists(_validatorId) {
        Validator storage validator = validators[_validatorId];
        require(validator.isActive, "Validator not active");
        require(!validator.certificateSlashed, "Certificate already slashed");

        validator.certificateSlashed = true;
        validator.slashedAmount = STAKE_AMOUNT;
        validator.stakedAmount = 0;

        // Mark all active certificates as invalid
        uint256[] memory certs = validatorCertificates[_validatorId];
        for (uint256 i = 0; i < certs.length; i++) {
            if (certificates[certs[i]].isValid) {
                certificates[certs[i]].isValid = false;
                certificates[certs[i]].slashTimestamp = block.timestamp;
            }
        }

        totalStakedAmount -= STAKE_AMOUNT;

        emit CertificateSlashed(
            validatorCertificates[_validatorId][0],
            _validatorId,
            validator.validatorAddress,
            STAKE_AMOUNT,
            block.timestamp
        );
    }

    // Deactivate validator
    function deactivateValidator(uint256 _validatorId) external onlyAdmin validatorExists(_validatorId) {
        validators[_validatorId].isActive = false;
        emit ValidatorDeactivated(_validatorId, validators[_validatorId].validatorAddress);
    }

    // Withdraw staked amount (only if not slashed)
    function withdrawStake(uint256 _validatorId) external validatorExists(_validatorId) {
        Validator storage validator = validators[_validatorId];
        require(msg.sender == validator.validatorAddress, "Not the validator");
        require(!validator.isActive, "Validator still active");
        require(!validator.certificateSlashed, "Stake was slashed");
        require(validator.stakedAmount > 0, "No stake to withdraw");

        uint256 amount = validator.stakedAmount;
        validator.stakedAmount = 0;
        totalStakedAmount -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit ValidatorWithdrawn(_validatorId, msg.sender, amount);
    }

    // Query functions
    function getValidator(uint256 _validatorId)
        external
        view
        validatorExists(_validatorId)
        returns (Validator memory)
    {
        return validators[_validatorId];
    }

    function getCertificate(uint256 _certificateId)
        external
        view
        returns (ValidationCertificate memory)
    {
        return certificates[_certificateId];
    }

    function getValidatorCertificates(uint256 _validatorId)
        external
        view
        returns (uint256[] memory)
    {
        return validatorCertificates[_validatorId];
    }

    function isValidatorActive(uint256 _validatorId) external view returns (bool) {
        return validators[_validatorId].isActive && !validators[_validatorId].certificateSlashed;
    }

    function getValidatorIdByAddress(address _validator) external view returns (uint256) {
        return validatorIdByAddress[_validator];
    }

    // Receive ETH
    receive() external payable {}
}
