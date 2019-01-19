defmodule BlockChain do
  import Bitcoin
  import Transaction

  defstruct chain: [newBlock("1/1/2018", [], 0)], difficulty: 2, miningRewards: 100, pendingTransactions: []

  def newChain do
    %BlockChain{}
  end

  def minePendingTransactions(blockchain, miningRewardAddress) do
    miningFee = Enum.reduce(blockchain.pendingTransactions, 0, fn x, acc -> acc + x.fee end)
    blockchain = addTransaction(blockchain, newTransaction(nil, miningRewardAddress, blockchain.miningRewards + miningFee))

    block =
      newBlock(
        DateTime.to_string(DateTime.utc_now()),
        blockchain.pendingTransactions,
        List.last(blockchain.chain).currentHash
      )

    block = mineBlock(block, blockchain.difficulty)

    blockchain = %{blockchain | chain: blockchain.chain ++ [block]}
    %{blockchain | pendingTransactions: []}
  end

  def getBalanceofAddress(blockchain, address) do
    blocks = blockchain.chain

      Enum.reduce(blocks, 0, fn x, acc ->
        transactions = x.transactions

        acc +
          Enum.reduce(transactions, 0, fn k, minacc ->
            cond do
              k.fromAddress == address -> minacc - k.amount - k.fee
              k.toAddress == address -> minacc + k.amount
              true -> minacc
            end
          end)
      end)
  end

  def addTransaction(chain, transaction) do
    if transaction.fromAddress == "" or transaction.toAddress == "" do
      throw("Transaction must include from and to address")
    end

    if !isValid(transaction) do
      throw("Cannot add invalid transaction to the chain")
    end

    if transaction.fromAddress != nil do
      if(getBalanceofAddress(chain, transaction.fromAddress) < transaction.amount + transaction.fee) do
        throw("Not enough Balance")
      else
        total = getBalanceofAddress(chain, transaction.fromAddress) - Enum.reduce(chain.pendingTransactions, 0 , fn x, acc -> acc + x.amount + x.fee end) - transaction.amount - transaction.fee
        if total < 0 do
          throw("You used all your balance")
        end
      end
    end
    %{chain | pendingTransactions: chain.pendingTransactions ++ [transaction]}
  end

  def isChainValid(blockchain) do
    blocks = blockchain.chain

    Enum.reduce(Enum.slice(blocks, 1, length(blocks)), true, fn x, acc ->
      previous = Enum.at(blocks, Enum.find_index(blocks, fn k -> x == k end) - 1)

      cond do
        !hasValidTransactions(x) -> acc and false
        getNewHash(x) != x.currentHash -> acc and false
        x.previousHash != previous.currentHash -> acc and false
        true -> acc and true
      end
    end)
  end

end
