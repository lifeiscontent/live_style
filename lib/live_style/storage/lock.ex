defmodule LiveStyle.Storage.Lock do
  @moduledoc false

  @lock_retry_interval 10
  # Consider a lock stale if older than 5 minutes (crashed process)
  @stale_lock_threshold_seconds 300

  @spec with_lock(String.t(), non_neg_integer(), (-> term())) :: term()
  def with_lock(lock_path, timeout, fun) when is_function(fun, 0) do
    # Clean stale locks before attempting to acquire
    maybe_clean_stale_lock(lock_path)
    acquire_lock(lock_path, timeout)

    try do
      fun.()
    after
      release_lock(lock_path)
    end
  end

  @doc """
  Removes a lock directory if it appears to be stale (from a crashed process).
  A lock is considered stale if it's older than 5 minutes.
  """
  def maybe_clean_stale_lock(lock_path) do
    case File.stat(lock_path) do
      {:ok, %{mtime: mtime}} ->
        age_seconds = System.os_time(:second) - to_unix_time(mtime)

        if age_seconds > @stale_lock_threshold_seconds do
          File.rm_rf(lock_path)
        end

      {:error, :enoent} ->
        :ok

      {:error, _reason} ->
        :ok
    end
  end

  defp to_unix_time({{year, month, day}, {hour, min, sec}}) do
    :calendar.datetime_to_gregorian_seconds({{year, month, day}, {hour, min, sec}}) -
      :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
  end

  defp acquire_lock(lock_path, timeout) when timeout > 0 do
    case File.mkdir(lock_path) do
      :ok ->
        :ok

      {:error, :eexist} ->
        Process.sleep(@lock_retry_interval)
        acquire_lock(lock_path, timeout - @lock_retry_interval)

      {:error, reason} ->
        raise RuntimeError,
          message: "Failed to acquire lock at #{lock_path}: #{inspect(reason)}"
    end
  end

  defp acquire_lock(lock_path, _timeout) do
    raise RuntimeError,
      message:
        "Timeout acquiring lock at #{lock_path}. " <>
          "Another process may be holding the lock. " <>
          "Try deleting #{lock_path} if no other process is running."
  end

  defp release_lock(lock_path) do
    File.rm_rf(lock_path)
  end
end
