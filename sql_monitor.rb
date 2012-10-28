$VERBOSE = false

class MysqlNagger < Scout::Plugin
  needs 'mysql'
  needs "rubygems"
  needs "json"

  OPTIONS=<<-EOS
  fancy_query:
    name: Fancy Query
    notes: This is either a straight shot SQL query or a JSON encoded string created with the configurator (https://github.com/kristopolous/scout-mysql-nagger/blob/master/configurator.html)
  credential_user:
    name: MySQL User
    notes: The MySQL User to log in as
  credential_password:
    name: MySQL Password
    notes: The MySQL User's password
  credential_db:
    name: MySQL DB
    notes: The MySQL DB to use (optional)
  EOS

  def build_report
    begin
      raw_query = option("fancy_query").to_s
      queryList = []

      begin
        queryList = JSON.parse(raw_query)
      rescue 
        queryList = ["result", raw_query.strip]
      end

      if queryList.empty?
        return error("A query wasn't provided.", "Please enter a query to monitor in the plugin settings.")
      end

      credentialMap = {
        :user => option("credential_user").to_s.strip,
        :password => option("credential_password").to_s.strip,
        :db => option("credential_db").to_s.strip
      }

      begin
        if credentialMap[:db].length > 0
          conn = Mysql.new "localhost", credentialMap[:user], credentialMap[:password], credentialMap[:db]
        else
          conn = Mysql.new "localhost", credentialMap[:user], credentialMap[:password]
        end

        queryList.each { | queryRow |
          name, query = queryRow
          result = conn.query(query)
          row = result.fetch_row
          report(name => row[0])
        }
      rescue Mysql::Error => e
        return error("Mysql Error.", "Mysql returned the error number #{e.errno} with the description #{e.error}")
      ensure
        conn.close if conn
      end

    rescue Exception => e
      error( "Uncaught exception occured.",
             "Ruby says: #{e.message}<br><br>#{e.backtrace.join('<br>')}" )
    end
  end
end
