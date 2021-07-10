// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {
    AggregatorV3Interface
} from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

contract Presale is Ownable {
    using SafeMath for uint256;

    // ERC20 tokens
    IERC20 public mbd;

    // Structure of each vest
    struct Vest {
        uint256 amount; // the amount of MBD the beneficiary will recieve
        uint256 released; // the amount of MBD released to the beneficiary
        bool ethTransferred; // whether the beneficiary has transferred the eth into the contract
    }

    // The mapping of vested beneficiary (beneficiary address => Vest)
    mapping(address => Vest) public vestedBeneficiaries;

    // beneficiary => eth deposited
    mapping(address => uint256) public ethDeposits;

    // Array of beneficiaries
    address[] public beneficiaries;

    // No. of beneficiaries
    uint256 public noOfBeneficiaries;

    // Whether the contract has been bootstrapped with the MBD
    bool public bootstrapped;

    // Start time of the the vesting
    uint256 public startTime;

    // The duration of the vesting
    uint256 public duration;

    // Price of each MBD token in usd (1e8 precision)
    uint256 public mbdPrice;

    // ETH/USD chainlink price aggregator
    AggregatorV3Interface internal priceFeed;

    constructor(address _priceFeedAddress, uint256 _mbdPrice) {
        require(_priceFeedAddress != address(0), 'Price feed address cannot be 0');
        require(_mbdPrice > 0, 'MBD price has to be higher than 0');
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        mbdPrice = _mbdPrice;

        // addBeneficiary(0x0330414bBF9491445c102A2a8a14adB9b6a25384, uint256(5000).mul(1e18));
    }

    /*---- EXTERNAL FUNCTIONS FOR OWNER ----*/

    /**
    * @notice Bootstraps the presale contract
    * @param _startTime the time (as Unix time) at which point vesting starts
    * @param _duration duration in seconds of the period in which the tokens will vest
    * @param _mbdAddress address of mbd erc20 token
    */
    function bootstrap(
        uint256 _startTime,
        uint256 _duration,
        address _mbdAddress
    ) external onlyOwner returns (bool) {
        require(_mbdAddress != address(0), 'MBD address is 0');
        require(_duration > 0, 'Duration passed cannot be 0');
        require(_startTime > block.timestamp, 'Start time cannot be before current time');

        startTime = _startTime;
        duration = _duration;
        mbd = IERC20(_mbdAddress);

        uint256 totalMBDRequired;

        for (uint256 i = 0; i < beneficiaries.length; i = i + 1) {
            totalMBDRequired = totalMBDRequired.add(vestedBeneficiaries[beneficiaries[i]].amount);
        }

        require(totalMBDRequired > 0, 'Total MBD required cannot be 0');

        mbd.transferFrom(msg.sender, address(this), totalMBDRequired);

        bootstrapped = true;

        emit Bootstrap(totalMBDRequired);

        return bootstrapped;
    }

    /**
    * @notice Adds a beneficiary to the contract. Only owner can call this.
    * @param _beneficiary the address of the beneficiary
    * @param _amount amount of MBD to be vested for the beneficiary
    */
    function addBeneficiary(address _beneficiary, uint256 _amount) public onlyOwner returns (bool) {
        require(_beneficiary != address(0), 'Beneficiary cannot be a 0 address');
        require(_amount > 0, 'Amount should be larger than 0');
        require(!bootstrapped, 'Cannot add beneficiary as contract has been bootstrapped');
        require(vestedBeneficiaries[_beneficiary].amount == 0, 'Cannot add the same beneficiary again');

        beneficiaries.push(_beneficiary);

        vestedBeneficiaries[_beneficiary].amount = _amount;

        noOfBeneficiaries = noOfBeneficiaries.add(1);

        emit AddBeneficiary(_beneficiary, _amount);

        return true;
    }

    /**
    * @notice Updates beneficiary amount. Only owner can call this.
    * @param _beneficiary the address of the beneficiary
    * @param _amount amount of MBD to be vested for the beneficiary
    */
    function updateBeneficiary(address _beneficiary, uint256 _amount) external onlyOwner {
        require(_beneficiary != address(0), 'Beneficiary cannot be a 0 address');
        require(!bootstrapped, 'Cannot update beneficiary as contract has been bootstrapped');
        require(
            vestedBeneficiaries[_beneficiary].amount != _amount,
            'New amount cannot be the same as old amount'
        );
        require(
            !vestedBeneficiaries[_beneficiary].ethTransferred,
            'Beneficiary should have not transferred ETH'
        );
        require(_amount > 0, 'Amount cannot be smaller or equal to 0');
        require(vestedBeneficiaries[_beneficiary].amount != 0, 'Beneficiary has not been added');

        vestedBeneficiaries[_beneficiary].amount = _amount;

        emit UpdateBeneficiary(_beneficiary, _amount);
    }

    /**
    * @notice Removes a beneficiary from the contract. Only owner can call this.
    * @param _beneficiary the address of the beneficiary
    * @return whether beneficiary was deleted
    */
    function removeBeneficiary(address payable _beneficiary) external onlyOwner returns (bool) {
        require(_beneficiary != address(0), 'Beneficiary cannot be a 0 address');
        require(!bootstrapped, 'Cannot remove beneficiary as contract has been bootstrapped');
        if (vestedBeneficiaries[_beneficiary].ethTransferred) {
            _beneficiary.transfer(ethDeposits[_beneficiary]);
        }
        for (uint256 i = 0; i < beneficiaries.length; i = i + 1) {
            if (beneficiaries[i] == _beneficiary) {
                noOfBeneficiaries = noOfBeneficiaries.sub(1);

                delete beneficiaries[i];
                delete vestedBeneficiaries[_beneficiary];

                emit RemoveBeneficiary(_beneficiary);

                return true;
            }
        }
        return false;
    }

    /**
    * @notice Withdraws eth deposited into the contract. Only owner can call this.
    */
    function withdraw() external onlyOwner {
        uint256 ethBalance = payable(address(this)).balance;

        payable(msg.sender).transfer(ethBalance);

        emit WithdrawEth(ethBalance);
    }

    /*---- EXTERNAL FUNCTIONS ----*/

    /**
    * @notice Transfers eth from beneficiary to the contract.
    */
    function transferEth() external payable returns (uint256 ethAmount) {
        require(
            !vestedBeneficiaries[msg.sender].ethTransferred,
            'Beneficiary has already transferred ETH'
        );
        require(vestedBeneficiaries[msg.sender].amount > 0, 'Sender is not a beneficiary');

        uint256 ethPrice = getLatestPrice();

        ethAmount = vestedBeneficiaries[msg.sender].amount.mul(mbdPrice).div(ethPrice);

        require(msg.value >= ethAmount, 'Incorrect ETH amount sent');

        if (msg.value > ethAmount) {
            payable(msg.sender).transfer(msg.value.sub(ethAmount));
        }

        ethDeposits[msg.sender] = ethAmount;

        vestedBeneficiaries[msg.sender].ethTransferred = true;

        emit TransferredEth(msg.sender, ethAmount, ethPrice);
    }

    /**
    * @notice Transfers vested tokens to beneficiary.
    */
    function release() external returns (uint256 unreleased) {
        require(bootstrapped, 'Contract has not been bootstrapped');
        require(vestedBeneficiaries[msg.sender].ethTransferred, 'Beneficiary has not transferred eth');
        unreleased = releasableAmount(msg.sender);

        require(unreleased > 0, 'No releasable amount');

        vestedBeneficiaries[msg.sender].released = vestedBeneficiaries[msg.sender].released.add(
            unreleased
        );

        mbd.transfer(msg.sender, unreleased);

        emit TokensReleased(msg.sender, unreleased);
    }

    /*---- VIEWS ----*/

    /**
    * @notice Calculates the amount that has already vested but hasn't been released yet.
    * @param beneficiary address of the beneficiary
    */
    function releasableAmount(address beneficiary) public view returns (uint256) {
        return vestedAmount(beneficiary).sub(vestedBeneficiaries[beneficiary].released);
    }

    /**
    * @notice Calculates the amount that has already vested.
    * @param beneficiary address of the beneficiary
    */
    function vestedAmount(address beneficiary) public view returns (uint256) {
        uint256 totalBalance = vestedBeneficiaries[beneficiary].amount;

        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= startTime.add(duration)) {
            return totalBalance;
        } else {
            uint256 halfTotalBalance = totalBalance.div(2);
            return
            halfTotalBalance.mul(block.timestamp.sub(startTime)).div(duration).add(halfTotalBalance);
        }
    }

    /**
    * @notice Returns the latest price for ETH/USD
    */
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    /*---- EVENTS ----*/

    event TokensReleased(address beneficiary, uint256 amount);

    event AddBeneficiary(address beneficiary, uint256 amount);

    event RemoveBeneficiary(address beneficiary);

    event UpdateBeneficiary(address beneficiary, uint256 amount);

    event TransferredEth(address beneficiary, uint256 ethAmount, uint256 ethPrice);

    event WithdrawEth(uint256 amount);

    event Bootstrap(uint256 totalMBDRequired);
}