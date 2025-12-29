// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CarbonToken
 * @dev ERC20 token for carbon credits with controlled minting/burning
 */
contract CarbonToken {
    string public name = "Aeris Carbon Credit";
    string public symbol = "ACC";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public verificationContract;
    address public carbonRetirementContract;
    address public admin;

    struct TokenMetadata {
        uint256 tokenId;
        uint256 projectId;
        uint256 amount; // CO2 equivalent in kg
        uint256 mintTimestamp;
        bool isRetired;
        uint256 retirementTimestamp;
    }

    mapping(uint256 => TokenMetadata) public tokenMetadata;
    uint256 public tokenCounter = 0;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokenMinted(
        uint256 indexed tokenId,
        uint256 indexed projectId,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    event TokenBurned(
        uint256 indexed tokenId,
        address indexed from,
        uint256 amount,
        uint256 timestamp
    );
    event VerificationContractSet(address indexed verificationContract);
    event CarbonRetirementContractSet(address indexed carbonRetirementContract);

    // Modifiers
    modifier onlyVerification() {
        require(
            msg.sender == verificationContract,
            "Only verification contract can call this"
        );
        _;
    }

    modifier onlyCarbonRetirement() {
        require(
            msg.sender == carbonRetirementContract,
            "Only carbon retirement contract can call this"
        );
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    // Constructor
    constructor() {
        admin = msg.sender;
    }

    // Admin functions
    function setVerificationContract(address _verificationContract) external onlyAdmin {
        verificationContract = _verificationContract;
        emit VerificationContractSet(_verificationContract);
    }

    function setCarbonRetirementContract(address _carbonRetirementContract)
        external
        onlyAdmin
    {
        carbonRetirementContract = _carbonRetirementContract;
        emit CarbonRetirementContractSet(_carbonRetirementContract);
    }

    // Minting function - only called by verification contract
    function mint(
        address _to,
        uint256 _amount,
        uint256 _projectId
    ) external onlyVerification returns (uint256) {
        require(_to != address(0), "Cannot mint to zero address");
        require(_amount > 0, "Amount must be greater than 0");

        uint256 tokenId = tokenCounter++;

        balanceOf[_to] += _amount;
        totalSupply += _amount;

        tokenMetadata[tokenId] = TokenMetadata({
            tokenId: tokenId,
            projectId: _projectId,
            amount: _amount,
            mintTimestamp: block.timestamp,
            isRetired: false,
            retirementTimestamp: 0
        });

        emit TokenMinted(tokenId, _projectId, _to, _amount, block.timestamp);
        emit Transfer(address(0), _to, _amount);

        return tokenId;
    }

    // Burning function - only called by carbon retirement contract
    function burn(address _from, uint256 _amount, uint256 _tokenId)
        external
        onlyCarbonRetirement
    {
        require(_from != address(0), "Cannot burn from zero address");
        require(balanceOf[_from] >= _amount, "Insufficient balance");
        require(!tokenMetadata[_tokenId].isRetired, "Token already retired");

        balanceOf[_from] -= _amount;
        totalSupply -= _amount;

        tokenMetadata[_tokenId].isRetired = true;
        tokenMetadata[_tokenId].retirementTimestamp = block.timestamp;

        emit TokenBurned(_tokenId, _from, _amount, block.timestamp);
        emit Transfer(_from, address(0), _amount);
    }

    // Standard ERC20 functions
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value)
        public
        returns (bool)
    {
        require(_from != address(0), "Invalid from address");
        require(_to != address(0), "Invalid to address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // Query functions
    function getTokenMetadata(uint256 _tokenId)
        external
        view
        returns (TokenMetadata memory)
    {
        return tokenMetadata[_tokenId];
    }
}
