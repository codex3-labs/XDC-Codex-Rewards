pragma solidity ^0.8.10;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//-------------------------- Plus Treasury Contract --------------------------
interface Plus_Interface {
    function View_Account() external view returns(uint); // -- ✓
    function Balance() external view returns(uint256);   // -- ✓
    function Accept_From_Codex(uint)external payable;
    function Redeem()external returns(bool);            // -- ✓
    function Register_Account()external returns(bool);  // -- ✓
    function Get_Codex() external view returns(address); // -- ✓
}
contract Plus is ERC20, Plus_Interface {
    uint counter =0;
    uint Account_Counter = 0;
    uint dust_min = 100; // amount of dust allowed in treasury per refreash
    uint i=0; // -- change to CurrentUserCount
    event TreasuryClock( uint256,bool);

    //mappings map Account amounts and micro ledger
    mapping (address => Accounts) public accounts;
    mapping (uint => micro_ledger) public ledger;
    
    //Codex Contract
    Codex[] public Codex_Contract;
    //Account Details
    struct Accounts{
        uint ammount;
        bool exist;
    }
    //Micrledger holds all accounts ever
    struct micro_ledger{
        address account;
        bool exist;
    }
    //launch Contract
    constructor(string memory name,string memory symbol,uint totalSupply,uint8 decimals) ERC20(name, symbol) {        
        totalSupply = totalSupply*(10**decimals);
        _mint(msg.sender, uint(totalSupply));
        Register_Account();
        //------------------launch Conbank Contract------------------
        Codex incomingbank = new Codex(address(this),totalSupply);
        Codex_Contract.push(incomingbank);
    }
    //require Codex 
    modifier CodexOnly{
        require(keccak256(abi.encodePacked(Codex_Contract[0])) == keccak256(abi.encodePacked(msg.sender)),"Only Contract Codex can execute this function");
        _;
    }
    //Test logging and accounting user dividends
    function Register_Account() public returns(bool){
        require(accounts[msg.sender].exist == false,"user already exist");
        ledger[Account_Counter] = micro_ledger(msg.sender,true);
        accounts[msg.sender] = Accounts(0,true);
        Account_Counter++;
        return true;
    }   
    //Account of your funds in contract
    function View_Account() public view returns(uint){
        require(accounts[msg.sender].exist == true,"user not registerd");
        return accounts[msg.sender].ammount;
    }
    //call contract balance
    function Balance() public view returns(uint256) {
        return address(this).balance;
    }
    //Accept payment from Codex and issue dividends to accouts
    function Accept_From_Codex(uint _singleShard)public payable CodexOnly{
        uint value = msg.value;
        uint totalAllocated=0;
        uint amountAllocated;
        uint dustSpread = value-totalAllocated;

        for(i;i<=Account_Counter;i++){
            (i,amountAllocated) = InternalAccounting(i,_singleShard);
            totalAllocated += amountAllocated;
            //refactor leftovers from unregisterd account & assimilate additional funds into treasury
            if(dustSpread<=dust_min){
                Codex_Interface(address(Codex_Contract[0])).Incomming_Payments{value:dustSpread}();
                break;
            }else if(i <= Account_Counter){
                i = i;
            }else{
                i = 0;
            }
        }
           emit TreasuryClock(block.timestamp,true); 
    }
    function InternalAccounting(uint _shardHolder,uint _singleShard)internal returns(uint,uint){
        address Serach_result = ledger[_shardHolder].account;
        if(ledger[_shardHolder].exist == true && accounts[Serach_result].ammount > 0){
            accounts[Serach_result].ammount += balanceOf(ledger[_shardHolder].account) * _singleShard;
        }
        return (_shardHolder,accounts[Serach_result].ammount);      
    }
    //Redeem Dividends from treasury
    function Redeem()public returns(bool){
        address payable RedeemAddress = payable(msg.sender);
        require(accounts[RedeemAddress].exist == true,"User does not exist");
        uint redeemValue = accounts[msg.sender].ammount;
        accounts[msg.sender].ammount=0;
        RedeemAddress.transfer(redeemValue);
        return true;     
    }
    function Get_Codex() public view returns(address){
        return address(Codex_Contract[0]);
    }
    
    fallback() external payable {}
    receive() external payable {}
}

//-------------------------- Codex Accounting Contract --------------------------
interface Codex_Interface{
    function Incomming_Payments()external payable returns(bool); // -- ✓
     function Balance() external view returns(uint256);
}
contract Codex is Codex_Interface{
    uint Shard_yeild_deposit; 
    uint public Supply;
    uint Fund_Retention_Rate; 
    event CodexClock(uint256,bool);
    address Treasury;
    address private TresuryContract;
    // Keep track of Funds in Codex
    struct Codex_Accounting{
        uint Previous_Time;
    }
    
    constructor(address _Treasury,uint _supply) payable{
        Treasury = _Treasury;
        Bank[Treasury] = Codex_Accounting(block.timestamp);   
        Supply = _supply;
        TresuryContract = payable(Treasury);
    }
    //Codex Index of all DAO Banks
    mapping (address => Codex_Accounting) public Bank;

    // Send funds to Treasury Contract
    function Issue_ToTreasury(uint _single_Shard)internal {
        // send data through interface function 

        //??? Error: done() called multiple times in test <Contract: function TruffleContract()???
        Plus_Interface(payable(Treasury)).Accept_From_Codex{value:address(this).balance, gas:7000000000000000000000000000000000000}(_single_Shard); //place treasury contract address here
        
        //payable(Treasury).transfer(address(this).balance); // test
        emit CodexClock(block.timestamp,true); 
    }
    // Payments to Codex will take account of funds and alocat them to the treasury
    function Incomming_Payments()public payable returns(bool){
        uint timeInterval=0; // add one timeInterval to the int 60
        if(block.timestamp>=timeInterval+Bank[Treasury].Previous_Time){
            uint single_Shard = uint(address(this).balance/Supply);
            Issue_ToTreasury(single_Shard); //Call Accept from Codex
            Bank[Treasury].Previous_Time = block.timestamp;
            return true;
        }else{
            return false;
        }
    }
    //call contract balance
    function Balance() public view returns(uint256) {
        return address(this).balance;
    }
    receive () external payable {
        Incomming_Payments();
    }
    fallback() external payable {}
}