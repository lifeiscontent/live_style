# Merge per-module data into the manifest before starting tests
# This ensures the manifest has compile-time data when Storage.fork() is called
LiveStyle.Storage.merge_module_data()

ExUnit.start()
