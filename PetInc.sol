// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract PetInc {
    // State Variables
    uint256 internal constant INITIAL_STARS = 100; // constant variable styled with UPPER CASE variable name
    bool internal locked; // to support reEntrancy guard
    address internal owner; // can be internal or private
    address[] internal customerAddresses; // use ARRAY for UNIQUE Identifiers
    string[] internal rewardNames; // user ARRAY for UNIQUE Identifiers
    struct Reward { // OKAY to declare struct after mapping
			string rewardName; // for mapping variable
			uint256 rewardPrize; // number of eth, all represented in gwei (10 ^ 18)
			uint256 starsNeeded; // number of stars to be deducted
			uint256 qty; // number of rewards available; check that not zero
		}
    mapping(address => uint256) internal petStars; // map customer address to stars
    mapping(string => Reward) internal rewards; // map rewardname to reward struct

    // Events
    event AccountCreated(address indexed account); // indexed means grouped by index
    event StarsEarned(address indexed account, uint256 starsEarned);
    event StarsRedeemed(address indexed account, uint256 starsRedeemed, string rewardName);

    // Functional Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action.");
        _;
    }
    
    modifier onlyCustomer() {
        require(customerExist(msg.sender), "You have not registered as a customer.");
        _;
    }
    
    modifier onlynewCustomer() {
        require(!customerExist(msg.sender), "You are already a customer.");
        _;
    }

    modifier reEntrancyGuard() { // check if log is locked, then unlock after all function steps are executed
        require(!locked, "This smart contract is locked at the moment."); // locked variable will be set to false in constructor
        locked = true; // temporary lock smart contract for all functions to complete execution
        _; // rest of function steps will be executed
        locked = false; // release locked after completion of all function steps
    }

    // Helper Functions
    function customerExist (address _custAddr) internal view returns (bool) { // view: reads but does not modify state variable
        for (uint256 i = 0; i < customerAddresses.length; i++) { // length = number of customer addresses in the DB
            address currAddr = customerAddresses[i];
            if (currAddr == _custAddr) {
                return true;
            }
        }
        return false;
    }
    
    function rewardExist (string memory _rewardName) internal view returns (bool) {
        for (uint256 i = 0; i < rewardNames.length; i++) {
            string memory currRewardName = rewardNames[i];
            if (stringsEqual(currRewardName, _rewardName)) {
                return true;
            }
        }
        return false;
    }
    
    function stringsEqual (string memory _strA, string memory _strB) internal pure returns (bool) {
        return keccak256(abi.encodePacked(_strA)) == keccak256(abi.encodePacked(_strB));
    }

    constructor() payable { //must be payable
        owner = msg.sender;
        locked = false;
    }
    
    receive() external payable { // special function which does not need the word function
    // empty coz not receiving, like a deposit box $ being put in only
    }

    function topUp() external payable onlyOwner { // function will be called externally
    // not changing any state hence no function body
    }
    
    // Functions
    function createAccount() public onlynewCustomer {
        address newCustAddr = msg.sender;
        customerAddresses.push(newCustAddr);
        petStars[msg.sender] = INITIAL_STARS;
        emit AccountCreated(newCustAddr);
    }

    function getStarsBalance() public view onlyCustomer returns (uint256) {
        return petStars[msg.sender];
    }

    function earnStars(uint256 _stars) public onlyCustomer {
        uint256 currStars = petStars[msg.sender]; // new variables cost gas!
        uint256 newStars = currStars + _stars; // new variables cost gas!
        petStars[msg.sender] = newStars;
       
        emit StarsEarned(msg.sender, _stars);
    }

    function redeemStars(string memory _rewardName) public onlyCustomer reEntrancyGuard { // always have reEntrancyGuard when transfer $ to caller
        require(rewardExist(_rewardName), "This reward does not exist.");
        Reward memory currReward = rewards[_rewardName]; // use memory if data can be discarded after function ends
        uint256 costOfReward = currReward.starsNeeded;
        uint256 custCurrStars = petStars[msg.sender];
        require(custCurrStars >= costOfReward, "You do not have enough stars for this reward.");
        
        uint256 custBalStars = custCurrStars - costOfReward;
        petStars[msg.sender] = custBalStars;

        currReward.qty -= 1;
        rewards[_rewardName] = currReward;

        (bool success, ) = payable(msg.sender).call{value: currReward.rewardPrize}("");
        require(success, "Transfer Failed");
        emit StarsRedeemed(msg.sender, costOfReward, _rewardName);
    }

    function addReward(
        string memory _rewardName, 
        uint256 _rewardCost, 
        uint256 _rewardPrize, 
        uint256 _rewardQty
    ) public onlyOwner {
        require(_rewardCost > 0, "Reward cost must be more than zero.");
        require(_rewardPrize > 0, "Reward prize must be more than zero.");
        require(_rewardQty > 0, "Reward qty must be more than zero.");
        require(!rewardExist(_rewardName), "This reward name already exists.");
        rewardNames.push(_rewardName);
        rewards[_rewardName] = Reward(_rewardName, _rewardCost, _rewardPrize, _rewardQty);
    }
}
