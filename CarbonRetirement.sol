// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CarbonToken.sol";

/**
 * @title CarbonRetirement
 * @dev Handles token retirement, burning, and offset recording
 */
contract CarbonRetirement {
    // Structs
    struct RetirementRecord {
        uint256 retirementId;
        address offsetter; // Usually an industry/company
        uint256 tokenId;
        uint256 carbonAmount; // CO2 equivalent in kg
        string retirementReason;
        uint256 retirementTimestamp;
        uint256 financialYear; // Year of retirement
        bool isPermanent;
    }

    struct IndustryAccount {
        address industryAddress;
        string industryName;
        uint256 totalCarbonBurned;
        uint256[] retirementRecords;
        bool isRegistered;
        uint256 registrationTimestamp;
    }

    struct AnnualOffset {
        uint256 year;
        address industry;
        uint256 totalOffsetAmount;
        uint256 offsetCount;
    }

    // State variables
    mapping(uint256 => RetirementRecord) public retirements;
    mapping(address => IndustryAccount) public industries;
    mapping(address => mapping(uint256 => AnnualOffset)) public annualOffsets;
    mapping(address => uint256[]) public industryRetirements;
    mapping(uint256 => bool) public burnedTokenIds;

    uint256 public retirementCounter = 0;
    address public carbonTokenAddress;
    address public admin;

    uint256 public constant SECONDS_PER_YEAR = 31536000;

    // Events
    event IndustryRegistered(
        address indexed industry,
        string industryName,
        uint256 timestamp
    );

    event CarbonOffsetRecorded(
        uint256 indexed retirementId,
        address indexed industry,
        uint256 tokenId,
        uint256 carbonAmount,
        uint256 financialYear,
        uint256 timestamp
    );

    event TokenPermanentlyBurned(
        uint256 indexed retirementId,
        address indexed industry,
        uint256 tokenId,
        uint256 carbonAmount,
        uint256 timestamp
    );

    event TokenRetired(
        uint256 indexed retirementId,
        address indexed industry,
        uint256 tokenId,
        uint256 carbonAmount,
        string reason,
        uint256 timestamp
    );

    event AnnualOffsetExpired(
        address indexed industry,
        uint256 year,
        uint256 totalOffsetAmount,
        uint256 timestamp
    );

    event OffsetAuditLog(
        address indexed industry,
        uint256 year,
        uint256 cumulativeOffset,
        bool canCarryForward,
        uint256 timestamp
    );

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyRegisteredIndustry() {
        require(industries[msg.sender].isRegistered, "Industry not registered");
        _;
    }

    // Constructor
    constructor(address _carbonTokenAddress) {
        carbonTokenAddress = _carbonTokenAddress;
        admin = msg.sender;
    }

    // Register industry
    function registerIndustry(
        string memory _industryName
    ) external returns (bool) {
        require(!industries[msg.sender].isRegistered, "Industry already registered");
        require(bytes(_industryName).length > 0, "Industry name cannot be empty");

        industries[msg.sender] = IndustryAccount({
            industryAddress: msg.sender,
            industryName: _industryName,
            totalCarbonBurned: 0,
            retirementRecords: new uint256[](0),
            isRegistered: true,
            registrationTimestamp: block.timestamp
        });

        emit IndustryRegistered(msg.sender, _industryName, block.timestamp);
        return true;
    }

    // Record carbon offset by burning tokens
    function offsetCarbonEmissions(
        uint256 _tokenId,
        uint256 _carbonAmount,
        string memory _retirementReason
    ) external onlyRegisteredIndustry returns (uint256) {
        require(_carbonAmount > 0, "Carbon amount must be greater than 0");
        require(!burnedTokenIds[_tokenId], "Token already burned");

        uint256 currentYear = getCurrentFinancialYear();

        // Get token metadata to verify it's valid
        CarbonToken(carbonTokenAddress).getTokenMetadata(_tokenId);

        // Call carbon token to burn the tokens
        CarbonToken(carbonTokenAddress).burn(msg.sender, _carbonAmount, _tokenId);

        uint256 retirementId = retirementCounter++;

        retirements[retirementId] = RetirementRecord({
            retirementId: retirementId,
            offsetter: msg.sender,
            tokenId: _tokenId,
            carbonAmount: _carbonAmount,
            retirementReason: _retirementReason,
            retirementTimestamp: block.timestamp,
            financialYear: currentYear,
            isPermanent: true
        });

        burnedTokenIds[_tokenId] = true;

        // Update industry account
        industries[msg.sender].totalCarbonBurned += _carbonAmount;
        industries[msg.sender].retirementRecords.push(retirementId);

        // Update annual offset
        AnnualOffset storage annualOffset = annualOffsets[msg.sender][currentYear];
        if (annualOffset.offsetCount == 0) {
            annualOffset.year = currentYear;
            annualOffset.industry = msg.sender;
        }
        annualOffset.totalOffsetAmount += _carbonAmount;
        annualOffset.offsetCount++;

        emit TokenPermanentlyBurned(retirementId, msg.sender, _tokenId, _carbonAmount, block.timestamp);
        emit CarbonOffsetRecorded(
            retirementId,
            msg.sender,
            _tokenId,
            _carbonAmount,
            currentYear,
            block.timestamp
        );
        emit TokenRetired(retirementId, msg.sender, _tokenId, _carbonAmount, _retirementReason, block.timestamp);

        return retirementId;
    }

    // Mark tokens as retired (without burning) - for record keeping
    function recordTokenRetirement(
        uint256 _tokenId,
        uint256 _carbonAmount,
        string memory _reason
    ) external onlyAdmin returns (uint256) {
        require(_carbonAmount > 0, "Carbon amount must be greater than 0");
        require(!burnedTokenIds[_tokenId], "Token already retired");

        uint256 currentYear = getCurrentFinancialYear();
        uint256 retirementId = retirementCounter++;

        retirements[retirementId] = RetirementRecord({
            retirementId: retirementId,
            offsetter: address(0),
            tokenId: _tokenId,
            carbonAmount: _carbonAmount,
            retirementReason: _reason,
            retirementTimestamp: block.timestamp,
            financialYear: currentYear,
            isPermanent: true
        });

        burnedTokenIds[_tokenId] = true;

        emit TokenRetired(
            retirementId,
            address(0),
            _tokenId,
            _carbonAmount,
            _reason,
            block.timestamp
        );

        return retirementId;
    }

    // Check if offset can be carried forward to next financial year
    function canCarryForwardOffset(address _industry, uint256 _year)
        external
        view
        onlyAdmin
        returns (bool)
    {
        AnnualOffset memory annualOffset = annualOffsets[_industry][_year];
        
        // Credits can be carried forward only if they exceed company's annual emissions
        // This is a simplified check - in production, compare with actual emissions data
        return annualOffset.totalOffsetAmount > 0;
    }

    // Expire offset credits at end of financial year
    function expireAnnualOffset(address _industry, uint256 _year)
        external
        onlyAdmin
        returns (uint256)
    {
        AnnualOffset storage annualOffset = annualOffsets[_industry][_year];
        require(annualOffset.year == _year, "Annual offset not found");

        uint256 expiredAmount = annualOffset.totalOffsetAmount;

        // Mark as expired by setting to 0
        annualOffset.totalOffsetAmount = 0;

        emit AnnualOffsetExpired(_industry, _year, expiredAmount, block.timestamp);

        return expiredAmount;
    }

    // Audit and verify offsets
    function auditIndustryOffsets(address _industry, uint256 _year)
        external
        view
        onlyAdmin
        returns (uint256, bool)
    {
        AnnualOffset memory annualOffset = annualOffsets[_industry][_year];

        bool canCarryForward = annualOffset.totalOffsetAmount > 0;

        emit OffsetAuditLog(_industry, _year, annualOffset.totalOffsetAmount, canCarryForward, block.timestamp);

        return (annualOffset.totalOffsetAmount, canCarryForward);
    }

    // Get current financial year (simplified: calendar year)
    function getCurrentFinancialYear() public view returns (uint256) {
        // In production, this would calculate the actual financial year
        // For now, using block.timestamp to get approximate year
        return (block.timestamp / SECONDS_PER_YEAR) + 1970;
    }

    // Query functions
    function getRetirementRecord(uint256 _retirementId)
        external
        view
        returns (RetirementRecord memory)
    {
        return retirements[_retirementId];
    }

    function getIndustryAccount(address _industry)
        external
        view
        returns (IndustryAccount memory)
    {
        return industries[_industry];
    }

    function getIndustryRetirements(address _industry)
        external
        view
        returns (uint256[] memory)
    {
        return industries[_industry].retirementRecords;
    }

    function getAnnualOffset(address _industry, uint256 _year)
        external
        view
        returns (AnnualOffset memory)
    {
        return annualOffsets[_industry][_year];
    }

    function isTokenBurned(uint256 _tokenId)
        external
        view
        returns (bool)
    {
        return burnedTokenIds[_tokenId];
    }

    function getTotalCarbonBurnedByIndustry(address _industry)
        external
        view
        returns (uint256)
    {
        return industries[_industry].totalCarbonBurned;
    }
}
