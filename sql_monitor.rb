$VERBOSE = false

class MysqlNagger < Scout::Plugin
  needs 'mysql'
  needs "rubygems"
  needs "json"

  OPTIONS=<<-EOS
  fancy_query:
    name: Fancy Query
    notes: This is either a straight shot SQL query or a JSON encoded string created with the configurator (https://github.com/kristopolous/scout-mysql-nagger/blob/master/configurator.html)
  credential_file:
    name: Credential File
    notes: Provide a path to a newline separated file with a username on the first line and a password on the second line and optionally, a database name on the third.
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
        :user => "",
        :password => "",
        :db => ""
      }

      begin
        credential_file = open(option("credential_file").to_s.strip)
        parts = credential_file.readlines
        credentialMap[:user] = parts.shift.strip
        credentialMap[:password] = parts.shift.strip
        credentialMap[:db] = parts.shift.strip if parts.length > 0
      rescue ENOENT => e
        return error("The file wasn't found.", "Please enter a valid path for the credentials.")
      rescue EACCESS => e
        return error("Permission denied.", "Please make sure that the scout user can read the credential file.")
      rescue
        return error("Unknown error.", "Please check the path and try again.")
      end

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
