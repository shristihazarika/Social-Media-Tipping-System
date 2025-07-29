// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SocialTipping
 * @dev A decentralized social media tipping system
 * @author YourName
 */
contract SocialTipping {
    
    // Events
    event TipSent(
        address indexed tipper,
        address indexed recipient,
        uint256 amount,
        string contentId,
        string message,
        uint256 timestamp
    );
    
    event CreatorRegistered(
        address indexed creator,
        string username,
        uint256 timestamp
    );
    
    event TipWithdrawn(
        address indexed creator,
        uint256 amount,
        uint256 timestamp
    );
    
    // Structs
    struct Creator {
        string username;
        uint256 totalTipsReceived;
        uint256 tipCount;
        bool isRegistered;
    }
    
    struct Tip {
        address tipper;
        address recipient;
        uint256 amount;
        string contentId;
        string message;
        uint256 timestamp;
    }
    
    // State variables
    mapping(address => Creator) public creators;
    mapping(address => uint256) public balances;
    mapping(string => Tip[]) public contentTips; // contentId => tips array
    Tip[] public allTips;
    
    address public owner;
    uint256 public platformFeePercentage = 250; // 2.5% (250/10000)
    uint256 public totalPlatformFees;
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredCreator() {
        require(creators[msg.sender].isRegistered, "Creator not registered");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Register as a content creator
     * @param _username Unique username for the creator
     */
    function registerCreator(string memory _username) external {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(!creators[msg.sender].isRegistered, "Creator already registered");
        
        creators[msg.sender] = Creator({
            username: _username,
            totalTipsReceived: 0,
            tipCount: 0,
            isRegistered: true
        });
        
        emit CreatorRegistered(msg.sender, _username, block.timestamp);
    }
    
    /**
     * @dev Send a tip to a content creator
     * @param _recipient Address of the content creator
     * @param _contentId ID of the content being tipped
     * @param _message Optional message with the tip
     */
    function sendTip(
        address _recipient,
        string memory _contentId,
        string memory _message
    ) external payable {
        require(msg.value > 0, "Tip amount must be greater than 0");
        require(_recipient != address(0), "Invalid recipient address");
        require(_recipient != msg.sender, "Cannot tip yourself");
        require(creators[_recipient].isRegistered, "Recipient not registered as creator");
        
        // Calculate platform fee
        uint256 platformFee = (msg.value * platformFeePercentage) / 10000;
        uint256 tipAmount = msg.value - platformFee;
        
        // Update balances
        balances[_recipient] += tipAmount;
        totalPlatformFees += platformFee;
        
        // Update creator stats
        creators[_recipient].totalTipsReceived += tipAmount;
        creators[_recipient].tipCount += 1;
        
        // Create tip record
        Tip memory newTip = Tip({
            tipper: msg.sender,
            recipient: _recipient,
            amount: tipAmount,
            contentId: _contentId,
            message: _message,
            timestamp: block.timestamp
        });
        
        // Store tip records
        contentTips[_contentId].push(newTip);
        allTips.push(newTip);
        
        emit TipSent(msg.sender, _recipient, tipAmount, _contentId, _message, block.timestamp);
    }
    
    /**
     * @dev Withdraw accumulated tips (only for registered creators)
     */
    function withdrawTips() external onlyRegisteredCreator {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No tips to withdraw");
        
        balances[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit TipWithdrawn(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Get creator information
     * @param _creator Address of the creator
     * @return Creator struct containing username, total tips, tip count, and registration status
     */
    function getCreatorInfo(address _creator) external view returns (Creator memory) {
        return creators[_creator];
    }
    
    /**
     * @dev Get tips for specific content
     * @param _contentId ID of the content
     * @return Array of tips for the content
     */
    function getContentTips(string memory _contentId) external view returns (Tip[] memory) {
        return contentTips[_contentId];
    }
    
    // Owner functions
    /**
     * @dev Withdraw platform fees (only owner)
     */
    function withdrawPlatformFees() external onlyOwner {
        uint256 amount = totalPlatformFees;
        require(amount > 0, "No fees to withdraw");
        
        totalPlatformFees = 0;
        
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Fee withdrawal failed");
    }
    
    /**
     * @dev Update platform fee percentage (only owner)
     * @param _newFeePercentage New fee percentage (in basis points, e.g., 250 = 2.5%)
     */
    function updatePlatformFee(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%"); // Max 10%
        platformFeePercentage = _newFeePercentage;
    }
    
    // View functions
    function getTotalTips() external view returns (uint256) {
        return allTips.length;
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
