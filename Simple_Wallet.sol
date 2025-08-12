// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleMultiSigWallet
 * @dev A simple multi-signature wallet with basic send/receive functions
 */
contract SimpleMultiSigWallet {
    // Events
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    // State variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        uint256 numConfirmations;
    }

    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    Transaction[] public transactions;

    // Modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "Transaction already confirmed");
        _;
    }

    /**
     * @dev Constructor to initialize the multi-sig wallet
     * @param _owners Array of owner addresses
     * @param _numConfirmationsRequired Number of confirmations required to execute a transaction
     */
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(
            _numConfirmationsRequired > 0 &&
            _numConfirmationsRequired <= _owners.length,
            "Invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /**
     * @dev Function 1: Receive Ether (automatically called when Ether is sent to contract)
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev Function 2: Submit a transaction for approval
     * @param _to Recipient address
     * @param _value Amount of Ether to send (in wei)
     */
    function submitTransaction(address _to, uint256 _value) public onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(_value > 0, "Value must be greater than 0");
        require(address(this).balance >= _value, "Insufficient balance");

        uint256 txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            executed: false,
            numConfirmations: 0
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value);
    }

    /**
     * @dev Function 3: Confirm a transaction
     * @param _txIndex Index of the transaction to confirm
     */
    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev Function 4: Execute a confirmed transaction
     * @param _txIndex Index of the transaction to execute
     */
    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "Cannot execute transaction - insufficient confirmations"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}("");
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /**
     * @dev Function 5: Get wallet balance
     * @return Current balance of the wallet in wei
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Additional view functions for frontend integration
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
