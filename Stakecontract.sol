 // SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

  import "./SafeMath.sol";
  import "./Pausable.sol";
  import "./IERC20.sol";
  import "./ReentrancyGuard.sol";
  import "./Ownable.sol";
  import "./IERC20.sol";
  import "./Context.sol";


 // @title Staking Pool Contract

contract Stakingpool is ReentrancyGuard,Pausable,Ownable{
  
    using SafeMath for uint;
    
   
    // MCH Token
   IERC20 public MCHToken;
   
   // MCF Token
   IERC20 public MCFToken;
  
  // @dev track total current stake yields of a user 
   mapping(address => uint) public currentstakeyields;
   
   // @dev track Stakedbalances of user
   mapping(address => uint) public stakedBalances;
  
   // @dev track StakedShares of user 
   mapping(address => uint) public stakedShares;
  
   // @dev track total staked amount of tokens of all users 
   uint public totalStakedMcH;
   
   // @dev track MCH value 
   uint public MCH;
  
   // @dev track MCF value
   uint public MCF;
  
   // @dev track total staked value of all users
   uint public totalStakedamount;
  
   // @dev track claimable tokens  
   mapping(address => uint) public claimable;
  
   // @dev track vested tokens   
   mapping(address => uint) public vested;
  
   // @dev track vested tokens 
   mapping(address => uint) public rewards;
 
   // @dev track users
   address[] public users;
   
   // blacklisting user 
   address[] public blackUsers;

  
   // @dev track index by address added to users 
   mapping(address => uint) private userIndex;
  
   /** @dev trigger notification of staked amount
    * @param sender       msg.sender for the transaction
    * @param amount       msg.value for the transaction
    */
   event NotifyStaked(address sender, uint amount);
  
   
   /** @dev trigger notification of unstaked amount
    * @param sender       msg.sender for the transaction
    * @param amount       msg.value for the transaction
    */
   event NotifyUnStaked(address sender, uint amount);


   // @dev trigger notification of claimed amount
   event Notifyclaimed(address sender,uint Balance);
  
  
   // @dev contract Initializable
    
    constructor (address _MCHToken, address _MCFToken)  {
    
         MCHToken = IERC20(_MCHToken);
         MCFToken = IERC20(_MCFToken);
    }

  
   /** @dev test if user is in current user list
    * @param user address of user to test if in list
    * @return true if user is on record, otherwise false
    */
   function isUser(address user) internal view returns(bool, uint256)  {
   
       for (uint256 i = 0; i < users.length; i += 1){
           if (user == users[i]) return (true, i);
       }
      
       return (false, 0);
    }
    
    /** @dev add a user to users array
    * @param user address of user to add to the list
    */
  
   function addUser(address user) internal  {
       
       (bool _isUser, ) = isUser(user);
       if(!_isUser) users.push(user);
    }
   
   
   // @dev remove a user from users array
    
    
    function removeUser(address user) internal  {
       
       (bool _isUser, uint256 i) = isUser(user);
       
       if(_isUser)  {
           users[i] = users[users.length.sub(1)];
           users.pop();
       }
    }
    
    // Blacklist users
    
    
     // blacklist recognition inspection
    function isBlackUser(address user) internal view returns(bool, uint256) {
       for (uint256 i = 0; i < blackUsers.length; i += 1){
           if (user == blackUsers[i]) return (true, i);
       }
       return (false, 0);
    }


      // Add Blacklist 
   function addBlackUser(address user) internal onlyOwner 
   {
       (bool _isBlackUser, ) = isBlackUser(user);
       if(!_isBlackUser) blackUsers.push(user);
   }
   
   
    // delete blacklist
   function removeBlackUser(address user) internal onlyOwner {
      
       (bool _isBlackUser, uint256 i) = isBlackUser(user);
       
       if(_isBlackUser){
           users[i] = blackUsers[users.length - 1];
           users.pop();
       }
   }
   
   
   // @dev stake funds to PoolContract
    
    function Approvestake(uint amount) external whenNotPaused {
     
      // staking amount cannot be zero
      require(amount > 0, "cannot be zero");
      
      // Adding users in to array
      if(stakedBalances[msg.sender] == 0) addUser(msg.sender);

      // Transfer Mock  tokens to this contract for staking
      MCHToken.transferFrom(msg.sender, address(this), amount);
      
      // updating stakedBalances
      stakedBalances[msg.sender] = stakedBalances[msg.sender].add(amount);
      
       // updating total staked MCH
      totalStakedMcH = totalStakedMcH.add(amount);
     
      // updating staked shares
       stakedShares[msg.sender]  = (stakedBalances[msg.sender].mul(100)).div(totalStakedMcH.add(amount));
      
      // triggering event 
      emit NotifyStaked(msg.sender, amount);
      
   }
   
   
   // @ dev unstake funds from Pool
    
    function unstake(uint amount) external whenNotPaused {
    
      // checking balances
      require(stakedBalances[msg.sender] >= amount, "unstaking balance cannot be 0");
      
      // starting balance
      uint InitialBalance = stakedBalances[msg.sender];
    
      // Final balance
      uint FinalBalance = InitialBalance.sub(amount);
    
      // Transfer MCH tokens 
      MCHToken.transfer(msg.sender,amount);
      
      // Reset staking Balances
      stakedBalances[msg.sender] = FinalBalance;
      
      // updating total staked MCH
      totalStakedMcH = totalStakedMcH.sub(amount);
      
      // updating shares
       stakedShares[msg.sender]= (stakedBalances[msg.sender].mul(100)).div(totalStakedMcH.sub(amount));
      
       if(stakedBalances[msg.sender] == 0) removeUser(msg.sender);
      
      // triggering event
       emit NotifyUnStaked(msg.sender, amount);
    }

   
   //  @ dev Fetching and distributing rewards to users
  
   function distributeRewards(uint256 rewardAmount) external onlyOwner {
       
       for (uint256 i = 0; i < users.length; i += 1) {
           address user = users[i];
           
        uint rate = stakedBalances[user].div(totalStakedMcH) ;  
        uint reward = rate.mul(rewardAmount);
        rewards[user] = rewards[user].add(reward);
       }
    }
    
    
    //  @ dev claiming rewards 

    function Harvest(uint amount) external  whenNotPaused nonReentrant() {
        
        // Require amount greater than 0
        require(rewards[msg.sender] >= amount, "amount cannot be 0");
        
        // transferring MCF tokens to users
        MCFToken.transfer(msg.sender, amount);
       
        // updating reward balances of users
        rewards[msg.sender] = rewards[msg.sender].sub(amount);

        // triggering event
        emit Notifyclaimed(msg.sender,amount);
    }
    
    
    //  admin withdraws MCF
    
     function withdrawMCF(address admin, uint amount) public {
	  MCFToken.transferFrom(address(this),admin,amount);
    }
  
}

    
   
   
   
   
   
   
   
   
   
   
   
   
