// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MCHToken} from "./MCHToken.sol";
import {MCFToken} from"./MCFToken.sol";



/* @title Staking Pool Contract
 * Open Zeppelin Pausable is Ownable.  contains address owner */

contract Stakingpool is Pausable {
  
  using SafeMath for uint;
  address private owner;
  
  
  MCHToken public mchtoken;
  MCFToken public mcftoken;
  uint public StakePeriod;
  
  modifier onlyOwner {
        require(
            msg.sender == owner,
            "Only owner can call this function."
        );
        _;
    }
  
 /** @dev track total current stake yields of a user */
   mapping(address => uint) public currentstakeyields;
   
   /** @dev track Stakedbalances of user*/
  mapping(address => uint) public stakedBalances;
  
  /** @dev track StakedShares of user */
  mapping(address => uint) public stakedShares;
  
  /** @dev track total staked amount of tokens of all users */
  uint public totalStakedMcH;
  
  /** @dev track total staked value of all users */
  uint public totalStakedamount;
  
 /** @dev track Daily Rate of Investment */
 mapping(address => uint) public DROI;
  
 /** @dev track Monthly Rate of Investment */
  mapping(address => uint) public MROI;
  
 /** @dev track Annual Rate of Investment */ 
  mapping(address => uint) public ROI;
  
  /** @dev track claimable tokens */ 
  mapping(address => uint) public claimable;
  
  /** @dev track vested tokens */  
  mapping(address => uint) public vested;
  
  /** @dev track user request to enter stakingPeriod */
  mapping(address => uint) public ApproveStake;
  
 /** @dev track users
    * users must be tracked in this array because mapping is not iterable */
  address[] public users;
  
   /** @dev track index by address added to users */
  mapping(address => uint) private userIndex;

  uint NoUsers;
  
 
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


  // @dev contract constructor
    
 constructor(MCHToken _mchtoken, MCFToken _mcftoken)  {
    
    owner = msg.sender;
    mchtoken = _mchtoken;
    mcftoken = _mcftoken;
    StakePeriod = block.timestamp + 15 days;
    
  }

  
  /************************ USER MANAGEMENT **********************************/

  /** @dev test if user is in current user list
    * @param _user address of user to test if in list
    * @return true if user is on record, otherwise false
    */
  function isExistingUser(address _user) internal view returns (bool) {
    
      for(uint256 i=0;i<users.length;i+=1) {
          if(_user ==users[i]) return(true);
      }
      
    return (false);
  }
  /** @dev remove a user from users array
    * @param _user address of user to remove from the list
    */
  function removeUser(address _user) internal {
    if (_user == owner ) return;
    uint index = userIndex[_user];
    // user is not last user
    if (index < users.length.sub(1)) {
      address lastUser = users[users.length.sub(1)];
      users[index] = lastUser;
      userIndex[lastUser] = index;
    }
    // this line removes last user
    users.length.sub(1);
  }

  /** @dev add a user to users array
    * @param _user address of user to add to the list
    */
   function addUser(address _user) internal {
    if (_user == owner ) return;
    if (!isExistingUser(_user)) users.push(_user);
   }
  /************************ USER MANAGEMENT **********************************/

  
   
  /** @dev stake funds to stakeContract
    */
  function Approvestake(uint amount) external {
      require(block.timestamp < StakePeriod );
      require(amount > 0);
      
     // Transfer Mock  tokens to this contract for staking
     mchtoken.transferFrom(msg.sender, address(this), amount);
    
    if(stakedBalances[msg.sender] == 0) addUser(msg.sender);
       stakedBalances[msg.sender] = stakedBalances[msg.sender].add(amount);
       
    // track total staked
    totalStakedMcH = totalStakedMcH.add(amount);

    emit NotifyStaked(msg.sender, amount);
  }


  /** @dev unstake funds from Pool
    */
  function unstake(uint amount) external  {
    
    // Fetch staking balance
    uint amount = stakedBalances[msg.sender];
    
    require(amount > 0, "staking balance cannot be 0");

    // Transfer Mocktokens 
    mcftoken.transfer(msg.sender, amount);

    // Reset staking balance
    stakedBalances[msg.sender] = stakedBalances[msg.sender].sub(amount);
    
    // track total staked
    totalStakedMcH = totalStakedMcH.sub(amount);

    emit NotifyUnStaked(msg.sender, amount);
  
   }

  
  function calcShares(address user) internal returns(uint) {
     
     uint shares = (stakedBalances[user].div(totalStakedMcH)).mul(100);
     stakedShares[user] = stakedShares[user].add(shares);
     return shares;
  }
  
  function calcRewards(address user) internal view returns (uint) {
      
      uint mcftokensEmitted = mcftoken.totalSupply();
      uint rewards = (stakedShares[user].mul(mcftokensEmitted)).div(100);
      return rewards;
  }
  
   function distributeRewards() public onlyOwner {
        
       require(block.timestamp >= StakePeriod );
       for (uint256 i = 0; i < users.length; i += 1) {
           address user = users[i];
           uint256 reward = calcRewards(user);
           currentstakeyields[user] = currentstakeyields[user].add(reward);
           vested[user] = currentstakeyields[user].div(2);
           claimable[user]=currentstakeyields[user].sub(vested[user]);
           mcftoken.transfer(user,claimable[user]);
       }
   }

    function Harvest() public  {
        
        uint256 Balance = claimable[msg.sender];
       // Require amount greater than 0
        require(Balance > 0, "balance cannot be 0");
        mcftoken.transfer(msg.sender, Balance);
       // payable(msg.sender).transfer(balance);
        claimable[msg.sender] = 0;

      emit Notifyclaimed(msg.sender,Balance);
    
    }
  
  function calcROI() public {
     
      for (uint256 i = 0; i < users.length; i += 1) {
        address user = users[i];
        ROI[user] =  (currentstakeyields[user].div(totalStakedMcH)).mul(100);
        MROI[user] = (ROI[user]).div(12);
        DROI[user] = (ROI[user]).div(365);
       }
    }

}
