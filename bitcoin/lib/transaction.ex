defmodule Transaction do
  defstruct fromAddress: nil, toAddress: nil, amount: nil, signature: nil, fee: 0

  def newTransaction(fromAddress, toAddress, amount, fee \\ 0) do
    %Transaction{fromAddress: fromAddress, toAddress: toAddress, amount: amount, fee: fee}
  end

  def calculateTxHash(transaction) do

    hashInput =
      Enum.join([
        transaction.fromAddress, transaction.toAddress, transaction.amount
      ])

    :crypto.hash(:sha256, hashInput) |> Base.encode16()
  end

  def signTransaction(transaction, publicKey, privateKey) do
    if publicKey != transaction.fromAddress do
      throw("You can't sign transactions for other wallets")
    end

    hash = calculateTxHash(transaction)
    %{transaction | signature: :crypto.sign(:ecdsa, :sha256, hash, [privateKey, :secp256k1])}
  end

  def isValid(transaction) do
    if transaction.fromAddress == nil do
      true
    else
      if transaction.signature == nil do
        throw("No signature in the transaction")
      end

      :crypto.verify(:ecdsa, :sha256, calculateTxHash(transaction), transaction.signature, [
       transaction.fromAddress,
        :secp256k1
      ])
    end
  end
end
