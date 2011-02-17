require 'helper'

# the famous memcache-client
require 'memcache'

class TestMemcacheStorage < Test::Unit::TestCase
  def setup
    super
    client = MemCache.new ['localhost:11211']
    client.flush_all
    Cache.config.client = client
  end
    
  include SharedTests
  
  def get_server_status_ids
    Cache.config.client.instance_variable_get(:@servers).map { |s| s.status.object_id }
  end
  
  def test_treats_as_thread_safe
    # make sure servers are connected
    Cache.get 'hi'
    
    # get the object ids
    main_thread_server_status_ids = get_server_status_ids
    
    # sanity check that it's not changing every time
    Cache.get 'hi'
    assert_equal main_thread_server_status_ids, get_server_status_ids
    
    # create a new thread and get its server ids
    new_thread_server_status_ids = Thread.new { Cache.get 'hi'; get_server_status_ids }.value
    
    # make sure the server ids was reinitialized
    assert_equal main_thread_server_status_ids, new_thread_server_status_ids
  end
  
  def test_treats_as_not_fork_safe
    # make sure server ids is initialized
    Cache.get 'hi'
    
    # get the main thread's server ids
    parent_process_server_status_ids = get_server_status_ids
    
    # sanity check that it's not changing every time
    Cache.get 'hi'
    assert_equal parent_process_server_status_ids, get_server_status_ids
    
    # fork a new process
    pid = Kernel.fork do
      Cache.get 'hi'
      raise "Didn't split!" if parent_process_server_status_ids == get_server_status_ids
    end
    Process.wait pid
    
    # make sure it didn't raise
    assert $?.success?
  end
end