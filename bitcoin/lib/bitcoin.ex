defmodule Bitcoin do
import Transaction
  defstruct timestamp: nil,  transactions: nil, previousHash: nil, currentHash: "", nonce: 0, merkleTreeRoot: nil

  def newBlock(timestamp, transactions, previousHash \\ "") do
    %Bitcoin{timestamp: timestamp, transactions: transactions, previousHash: previousHash}
  end

  def calculateHash(block) do
    hashInput =
    Enum.join([
      block.previousHash, block.nonce, block.timestamp, Kernel.inspect(block.transactions)
    ])

    hash = :crypto.hash(:sha256, hashInput) |> Base.encode16()
    %{block | currentHash: hash}
    end

  def mineBlock(block, difficulty) do
    if String.slice(block.currentHash, 0..(difficulty - 1)) != String.duplicate("0", difficulty) do
      block = %{block | nonce: block.nonce + 1}
      block = calculateHash(block)
      mineBlock(block, difficulty)
    else
      block = calculateMerkleTreeRoot(block, Enum.map(block.transactions, fn x ->
        :crypto.hash(:sha256, Enum.join([x.fromAddress, x.toAddress, x.amount, x.signature]))|> Base.encode16()
      end))
      block
    end
  end

  def calculateMerkleTreeRoot(block, transactions) do
    if length(transactions) == 1 do
      %{block | merkleTreeRoot: List.last(transactions)}
    else
      transactions = if rem(length(transactions), 2) == 1 do
        transactions ++ [List.last(transactions)]
      else
        transactions
      end
      transactions = Enum.reduce(Enum.take_every(1..length(transactions), 2), [], fn x, acc -> acc ++ [:crypto.hash(:sha256, Enum.join([Enum.at(transactions, x),  Enum.at(transactions, x+1)])) |> Base.encode16] end)
      calculateMerkleTreeRoot(block, transactions)
    end
  end

  def hasValidTransactions(block) do
    transactions = block.transactions

    Enum.reduce(transactions, true, fn x, acc ->
      acc and isValid(x)
    end)
  end

  def getNewHash(block) do
    hashInput =
    Enum.join([
      block.previousHash, block.nonce, block.timestamp, Kernel.inspect(block.transactions)
    ])

    :crypto.hash(:sha256, hashInput) |> Base.encode16()
  end
end
