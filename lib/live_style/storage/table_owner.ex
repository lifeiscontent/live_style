defmodule LiveStyle.Storage.TableOwner do
  @moduledoc """
  A simple GenServer that owns the ETS cache table.

  This process exists solely to own the ETS table, preventing the
  "Supervisor received unexpected message: ETS-TRANSFER" warnings
  that occur when using supervisor processes as heirs.

  The GenServer creates a public ETS table that other processes can
  read from and write to directly. This process just keeps the table
  alive for the lifetime of the application.
  """

  use GenServer

  @table_name :live_style_manifest_cache

  @doc """
  Starts the table owner process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the ETS table name.
  """
  def table_name, do: @table_name

  @doc """
  Ensures the table exists. Creates it if needed.
  Called by Cache module before any table operations.
  """
  def ensure_table do
    case :ets.whereis(@table_name) do
      :undefined ->
        # Table doesn't exist - try to start the owner process
        # In compilation (no application), we fall back to creating without owner
        case GenServer.whereis(__MODULE__) do
          nil ->
            # No owner process - create table owned by current process
            # This happens during compilation before the app starts
            create_table_fallback()

          _pid ->
            # Owner exists, table should exist (race condition - retry)
            :timer.sleep(10)
            ensure_table()
        end

      _tid ->
        :ok
    end
  end

  # Fallback table creation for when the owner process isn't running
  # (e.g., during compilation)
  defp create_table_fallback do
    :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    :ok
  rescue
    # Table was created by another process
    ArgumentError -> :ok
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Create the ETS table, owned by this process
    # No :heir needed - this process stays alive
    table = get_or_create_table()
    {:ok, %{table: table}}
  end

  defp get_or_create_table do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])

      tid ->
        tid
    end
  end

  @impl true
  def handle_info({:"ETS-TRANSFER", _table, _from_pid, _data}, state) do
    # Handle table transfer gracefully (if it ever happens)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
