// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./DarkMatter_DMD.sol";



pragma solidity ^0.6.12;

interface IMasterChef {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function enterStaking(uint256 _amount) external;
    function leaveStaking(uint256 _amount) external;
    function pendingDMD(uint256 _pid, address _user) external view returns (uint256);
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);
    function emergencyWithdraw(uint256 _pid) external;

}   

pragma solidity ^0.6.12;
// MasterChef is the master of DMD. He can make DMD and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once DMD is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef_DarkMatter_DMD is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of DMDs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accDMDPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accDMDPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. DMDs to distribute per block.
        uint256 lastRewardTime;  // Last block number that DMDs distribution occurs.
        uint256 accDMDPerShare;   // Accumulated DMDs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
    }

    // The DMD TOKEN!
    DarkMatter public DMD;
    // Dev address.
    address public dev_address;
    // DMD tokens created per block.
    uint256 public DMDPerSecond;
    // Bonus muliplier for early DMD makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Deposit Fee address
    address public feeAddress;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    //a maximum of 2 per second is set.
    uint256 public constant maxDMDPerSecond = 2e18;
    // Timestamp startTime.
    uint256 public startTime;

    // events 
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event Setdev_address(address indexed user, address indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 DMDPerSecond);

    constructor(
        DarkMatter _DMD,
        uint256 _DMDPerSecond,
        uint256 _startTime
    ) public {
        DMD = _DMD;
        dev_address = msg.sender;
        feeAddress = msg.sender;
        DMDPerSecond = _DMDPerSecond;
        startTime = _startTime;
   
        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _DMD,
            allocPoint: 1000,
            lastRewardTime: startTime,
            accDMDPerShare: 0,
            depositFeeBP: 0
        }));

        totalAllocPoint = 1000;

    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner nonDuplicated(_lpToken) {
        // deposit fee can't excess more than 10%
        require(_depositFeeBP <= 1000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(PoolInfo({
        lpToken : _lpToken,
        allocPoint : _allocPoint,
        lastRewardTime : lastRewardTime,
        accDMDPerShare : 0,
        depositFeeBP : _depositFeeBP
        }));
        updateStakingPool();
    }

    // Update the given pool's DMD allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 1000, "set: invalid deposit fee basis points"); // 1000 is 10% 
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
        updateStakingPool();
    }
    
       function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(points);
            poolInfo[0].allocPoint = points;
        }
    }
 
    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending DMDs on frontend.
    function pendingDMD(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDMDPerShare = pool.accDMDPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp >  pool.lastRewardTime && lpSupply != 0) {
            uint256 multiplier = getMultiplier( pool.lastRewardTime, block.timestamp);
            uint256 DMDReward = multiplier.mul(DMDPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            accDMDPerShare = accDMDPerShare.add(DMDReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accDMDPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <=  pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
             pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier( pool.lastRewardTime, block.timestamp);
        uint256 DMDReward = multiplier.mul(DMDPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
        DMD.mint(dev_address, DMDReward.div(10));
        DMD.mint(address(this), DMDReward);
        pool.accDMDPerShare = pool.accDMDPerShare.add(DMDReward.mul(1e12).div(lpSupply));
         pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for DMD allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require (_pid != 0, 'deposit DMD by staking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accDMDPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeDMDTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accDMDPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        require (_pid != 0, 'withdraw DMD by unstaking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accDMDPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeDMDTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accDMDPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
     // Stake  DMD tokens to MasterChef
    
    function enterStaking(uint256 _amount) public nonReentrant  {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accDMDPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeDMDTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accDMDPerShare).div(1e12);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw DMD tokens from STAKING.
    function leaveStaking(uint256 _amount) public nonReentrant  {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accDMDPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeDMDTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accDMDPerShare).div(1e12);

        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe DMD transfer function, just in case if rounding error causes pool to not have enough DMDs.
    function safeDMDTransfer(address _to, uint256 _amount) internal {
        uint256 DMDBal = DMD.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > DMDBal) {
            transferSuccess = DMD.transfer(_to, DMDBal);
        } else {
            transferSuccess = DMD.transfer(_to, _amount);
        }
        require(transferSuccess, "safeDMDTransfer: transfer failed");
    }

    // Update dev address by the previous dev.
    function dev(address _dev_address) public onlyOwner {
        require(msg.sender == dev_address, "setDev_Address: FORBIDDEN");
        require(_dev_address != address(0), "setDev_Address: ZERO");
        dev_address = _dev_address; 
        emit Setdev_address(msg.sender, _dev_address);
    }
      // Update fee address by the previous dev.
    function setFeeAddress(address _feeAddress) public onlyOwner {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        require(_feeAddress != address(0), "setFeeAddress: ZERO");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

   // Update DMD per Second
    function setDMDPerSecond (uint256 _DMDPerSecond) public onlyOwner {
        require(_DMDPerSecond <= maxDMDPerSecond, "setDMDPerSecond: you are stupid? max 2!");
        massUpdatePools();
        DMDPerSecond = _DMDPerSecond;
    }
}
