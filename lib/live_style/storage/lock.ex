defmodule LiveStyle.Storage.Lock do
  @moduledoc false

  @lock_retry_interval 10

  @spec with_lock(String.t(), non_neg_integer(), (-> term())) :: term()
  def with_lock(lock_path, timeout, fun) when is_function(fun, 0) do
    acquire_lock(lock_path, timeout)

    try do
      fun.()
    after
      release_lock(lock_path)
    end
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
    File.rm_rf(lock_path)
    File.mkdir!(lock_path)
  end

  defp release_lock(lock_path) do
    File.rm_rf(lock_path)
  end
end
