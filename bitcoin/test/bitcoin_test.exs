defmodule BitcoinTest do
  use ExUnit.Case
  import Bitcoin
  import Transaction
  import BlockChain
  import Client

  test "Creates a blockchain" do
    blockchain = newChain()
    assert Enum.at(blockchain.chain, 0).timestamp == "1/1/2018"
    assert blockchain.difficulty == 2
    assert blockchain.miningRewards == 100
  end
  test "Creates a block" do
    block = newBlock("Now",  [], "")
    assert block.timestamp == "Now"
    assert block.transactions == []
    assert block.nonce == 0

  end
  test "Creates a transaction" do
    txn = newTransaction("fromAddress", "toAddress", 100)
    assert txn.fromAddress == "fromAddress"
    assert txn.toAddress == "toAddress"
    assert txn.amount == 100
  end

  test "Invalid Transactions check" do
    blockchain = newChain()
    # No from address
    txn = newTransaction("", "publicKeyofReceiver", 10)
    block = catch_throw(addTransaction(blockchain, txn))
    assert block == "Transaction must include from and to address"
    # Unsigned Transaction
    {myWalletAddress, privateKey} = :crypto.generate_key(:ecdh, :secp256k1)
    txn = %{txn | fromAddress: myWalletAddress}
    block = catch_throw(addTransaction(blockchain, txn))
    assert block == "No signature in the transaction"
    # Wrongly signed Transaction
    txn = %{txn | signature: "Random other signature"}
    block = catch_throw(addTransaction(blockchain, txn))
    assert block == "Cannot add invalid transaction to the chain"
    # Legit Transaction
    txn = signTransaction(txn, myWalletAddress, privateKey)
    block = catch_throw(addTransaction(blockchain, txn))
    assert block == "Not enough Balance"
    blockchain = minePendingTransactions(blockchain, myWalletAddress)
    txn = signTransaction(txn, myWalletAddress, privateKey)
    blockchain = addTransaction(blockchain, txn)
    assert List.last(blockchain.pendingTransactions) == txn
  end

  test "Invalid Block check" do
    block = newBlock("Now", [])
    block = calculateHash(block)
    assert block.currentHash == getNewHash(block)
    # Change the block and invalidate it
    block = %{block | timestamp: "New Time"}
    assert block.currentHash != getNewHash(block)
  end

  test "Invalid Blockchain check" do
    blockchain = newChain()
    {myWalletAddress, privateKey} = :crypto.generate_key(:ecdh, :secp256k1)
    txn = newTransaction(myWalletAddress, "publickey", 10)
    txn = signTransaction(txn, myWalletAddress, privateKey)
    block = catch_throw(addTransaction(blockchain, txn))
    assert block == "Not enough Balance"
    blockchain = minePendingTransactions(blockchain, myWalletAddress)
    blockchain = addTransaction(blockchain, txn)
    blockchain = minePendingTransactions(blockchain, myWalletAddress)
    assert isChainValid(blockchain) == true # Chain valid so far

    #Tampering with a transaction after the block is mined
    txn = %{txn| amount: 1000}
    block = Enum.at(blockchain.chain, 1)
    block = %{block | transactions: List.replace_at(block.transactions, 0, txn)}
    blockchain = %{blockchain | chain: List.replace_at(blockchain.chain, 1, block)}
    assert isChainValid(blockchain) == false # Chain invalid
  end

  test "Hashing check" do
    block = newBlock(DateTime.to_string(DateTime.utc_now), [])
    block = calculateHash(block)
    assert :crypto.hash(:sha256, Enum.join([
      block.previousHash, block.nonce, block.timestamp, Kernel.inspect(block.transactions)
    ])) |> Base.encode16 == block.currentHash

    txn = newTransaction("fromAddress", "toAddress", 10)
    hash = calculateTxHash(txn)
    assert hash == :crypto.hash(:sha256, Enum.join([txn.fromAddress, txn.toAddress, txn.amount])) |> Base.encode16
  end

  test "Basic functionality test with wallet" do
    blockchain = newChain()
    client1 = newClient()
    client2 = newClient()
    client3= newClient()
    blockchain = minePendingTransactions(blockchain, getWalletAddress(client1))
    # Send 10 from wallet1 to wallet2 with 10 as fee
    txn = createTransaction(client1, getWalletAddress(client2), 10, 10)
    blockchain = addTransaction(blockchain, txn)
    # Send 100 from wallet 1 to wallet 2
    txn = createTransaction(client1, getWalletAddress(client2), 100)
    block = catch_throw(addTransaction(blockchain, txn))
    assert block == "You used all your balance"
    # Send 50 from wallet 1 to wallet 2
    txn = createTransaction(client1, getWalletAddress(client2), 50)
    blockchain = addTransaction(blockchain, txn)
    # Mine and send the rewards to wallet 3
    blockchain = minePendingTransactions(blockchain, getWalletAddress(client3))
    assert isChainValid(blockchain) == true
    # 100-10-10-50 = 30
    assert getBalanceofAddress(blockchain, getWalletAddress(client1)) == 30
    # 10+50 = 60
    assert getBalanceofAddress(blockchain, getWalletAddress(client2)) == 60
    # 100+10 = 110
    assert getBalanceofAddress(blockchain, getWalletAddress(client3)) == 110
  end
end
