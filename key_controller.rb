require 'Mysql2'
require 'securerandom'
require 'thread'
require_relative 'db_config'

class Key_controller

  def initialize(max_time_to_live = 300, max_time_to_block = 60)
    @client = Mysql2::Client.new(:host => DB_HOST, :username => DB_USER, :password => DB_PASS)
    @client.query("CREATE DATABASE IF NOT EXISTS KeyServer;")
    @client.query("use KeyServer;")
    @client.query("create table if not exists keys_table (key_id VARCHAR(50), blocked int, keep_alive int);")
    @max_time_to_live = max_time_to_live
    @max_time_to_block = max_time_to_block
    @lock = Mutex.new
  end

  def generate_keys
    keys = []
    10.times {
      key = SecureRandom.urlsafe_base64
      @lock.synchronize {
        while(key_exist?(key))
          key = SecureRandom.urlsafe_base64
        end
        @client.query("INSERT INTO keys_table VALUES ('#{key}', 0, #{Time.now.to_i})")
        keys.push(key)
      }
    }
    return keys
  end

  def key_exist?(key)
    res = @client.query("SELECT * FROM keys_table where key_id = '#{key}'")
    if res.first
      return res.first["key_id"]
    else
      return false
    end
  end

  def get_key
    @lock.synchronize {
      first_available_key = @client.query("SELECT key_id FROM keys_table WHERE blocked = 0 limit 1;")
      if first_available_key.first
        key = first_available_key.first["key_id"]
        @client.query("UPDATE keys_table set blocked = 1 where key_id = '#{key}';")
        return key
      end
      return false

    }
  end

  def unblock_key(key)
    @lock.synchronize {
      if key_exist?(key)
        @client.query("UPDATE keys_table set blocked = 0 where key_id = '#{key}'")
        return true
      end
      return false
    }
  end

  def delete_key(key)
    @lock.synchronize {
      if key_exist?(key)
        @client.query("DELETE from keys_table where key_id = '#{key}'")
        return true
      end
      return false
    }
  end

  def keep_alive(key)
    @lock.synchronize{
        curr_time = Time.now.to_i
        @client.query("UPDATE keys_table SET keep_alive = #{curr_time}  WHERE key_id = '#{key}'")
    }
  end

  def clean_keys
    curr_time = Time.now.to_i
    @lock.synchronize do
      @client.query("DELETE FROM keys_table WHERE #{curr_time} - keep_alive > #{@max_time_to_live}")
      @client.query("UPDATE keys_table SET block_last = 0 WHERE #{curr_time} - block_last > #{@max_time_to_block}")
    end
  end

  private :key_exist?
end
