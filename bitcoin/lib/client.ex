defmodule Client do
  import Transaction
  use GenServer

  def newClient() do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    GenServer.cast(pid, {:createWallet})
    pid
  end

  def createTransaction(pid, toAddress, amount, fee \\ 0 ) do
    GenServer.call(pid, {:createTransaction, [toAddress, amount, fee]})
  end

  def getWalletAddress(pid) do
    GenServer.call(pid, {:getWalletAddress})
  end

  def init(_args) do
    {:ok, %{}}
  end

  def handle_cast({:createWallet}, _state) do
    {walletAddress, privateKey} = :crypto.generate_key(:ecdh, :secp256k1)
    {:noreply, %{ "walletAddress" => walletAddress, "privateKey" => privateKey}}
  end

  def handle_call({:createTransaction, [toAddress, amount, fee]}, _from, state) do
    txn = newTransaction(Map.get(state, "walletAddress"), toAddress, amount, fee)
    txn = signTransaction(txn, Map.get(state, "walletAddress"), Map.get(state, "privateKey"))
    {:reply, txn, state}
  end

  def handle_call({:getWalletAddress}, _from, state) do
    {:reply, Map.get(state, "walletAddress"), state}
  end
end
