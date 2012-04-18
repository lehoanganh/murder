# Copyright 2010 Twitter, Inc.
# Copyright 2010 Larry Gadea <lg@twitter.com>
# Copyright 2010 Matt Freels <freels@twitter.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

namespace :kcsd do
	# =============================================================================================================
  # @author: lha
	# STEP 1
	# occur in all nodes (Seeder/Tracker/Peer)
	# PREPARATION FOR THE DISTRIBUTION
  # 1. distribute the Murder supported files from Murder Server to all nodes in the Murder folder (Seeder/Tracker/Peer)
  # 2. create a Distribution folder for the distributed files in all nodes (Seeder/Tracker/Peer)
  # ============================================================================================================= 
  desc <<-DESC
  SCPs a compressed version of all files from ./dist (the python Bittorrent library and custom scripts) to all servers. The entire directory is sent, regardless of the role of each individual server. The path on the server is specified by murder_path and will be cleared prior to transferring files over.
  DESC
  task :prepare_distribution, :roles => [:tracker, :seeder, :peer] do
		
		# CHECK
		check		
		
		# INFO
		puts "::::::::::::::::: Murder Server will create a Murder folder and distribute the Murder supported files to all nodes. These files are needed for the distribution via BitTorrent"
		puts "::::::::::::::::: The Murder directory is: #{murder_path}"
		puts "::::::::::::::::: Murder Server will create a Distribution folder in all nodes. This folder will contain the distributed files"
		puts "::::::::::::::::: The Distribution directory is: #{distribution_path}"
		puts ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"

		# delete the $HOME/.ssh/known_hosts file
		# because EC2 instances can be assigned to the dedicated IP address many times
		system "if [ -e $HOME/.ssh/known_hosts ]; then rm $HOME/.ssh/known_hosts; fi"

    # the supported folder which will be distributed to all nodes
		# this folder is located in Murder Server
    dist_path = File.expand_path('../../../dist', __FILE__)

    # if the Murder supported folder does NOT exist then create a new murder folder
		puts "::::::::::::::::: If the Murder supported folder does NOT exist then create a new murder folder"
		run "if [ ! -d #{murder_path} ]; then mkdir -p #{murder_path}; fi"
		
		# if the Distribution folder exists already, the delete it and create a new distribution folder
		puts "::::::::::::::::: If the Distribution folder exists already, then delete it and create a new Distribution folder"		
		run "if [ -d #{distribution_path} ]; then rm -rf #{distribution_path}; else mkdir -p #{distribution_path}; fi"
		
		# tar the dist folder
		puts "::::::::::::::::: Taring the dist folder in Murder Server"
		system "tar -c -z -C #{dist_path} -f #{temp_path}/murder_dist.tgz ."

		# upload the tar file from Muder Server to all nodes via sftp
		puts "::::::::::::::::: Uploading the tar file from Muder Server to all nodes via sftp"
    upload("#{temp_path}/murder_dist.tgz", "#{temp_path}/murder_dist.tgz", :via => :sftp)

		# untar the tar file to Murder folder
		puts "::::::::::::::::: Untaring the tar file to Murder folder"
    run "tar xf #{temp_path}/murder_dist.tgz -C #{murder_path}"
 
	end



	# =============================================================================================================
  # @author: lha
	# STEP 3
	# occur in the Seeder/Tracker
	# GE THE SOURCE FILES FOR THE SEEDER/TRACKER
  # ============================================================================================================= 
	desc "The Seeder fetchs the source files"
	task :get_source_files_for_the_seeder, :roles => :seeder do
		
		# CHECK		
		check

		# INFO
		puts "::::::::::::::::: The Seeder/Tracker will fetch the source files"
		puts ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"

		# wget the source files
		puts "::::::::::::::::: Downloading the source files"
		run "wget #{source_files_path} -nv -O #{filename}"

		# untar into the distribution folder
		puts "::::::::::::::::: Untaring into the Distribution folder"
		run "tar -xzf #{filename} --strip-components=1 -C #{distribution_path}"

	end



	# =============================================================================================================
  # @author: lha
	# STEP 4
  # occur in the Seeder/Tracker
	# CREATE A .TORRENT FILE IN #{temp_path}
  # =============================================================================================================
  desc <<-DESC
  Compresses the directory specified by the passed-in argument 'files_path' and creates a .torrent file identified by the 'tag' argument. Be sure to use the same 'tag' value with any following commands. Any .git directories will be skipped. Once completed, the .torrent will be downloaded to your local /tmp/TAG.tgz.torrent.
  DESC
  task :create_torrent_in_the_seeder, :roles => :seeder do

    # CHECK
		check

		# INFO
		puts "::::::::::::::::: The Seeder/Tracker will create a .torrent file for the source files"
		puts ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"

    # tracker's information
    tracker = find_servers(:roles => :tracker).first
    tracker_host = tracker.host
    tracker_port = variables[:tracker_port] || '8998'

    # create the .torrent file in the seeder, the .torrent is saved in #{temp_path}
		puts "::::::::::::::::: Crearing a .torrent file on Tracker/Seeder"
		run "python #{murder_path}/murder_make_torrent.py '#{filename}' #{tracker_host}:#{tracker_port} '#{filename}.torrent'"

		# get the torrent file from the Seeder to Murder Server
		puts "::::::::::::::::: Downloading the new .torrent file to Murder Server"
		download("#{filename}.torrent","#{filename}.torrent")

  end


  # =============================================================================================================
  # @author: lha
	# STEP 5
  # occur in the Seeder
	# START SEEDING
  # modify the original code
  # don't use host $HOSTNAME to capture the IP address of the seeder anymore
  # ============================================================================================================= 
  desc <<-DESC
  Will cause the seeder machine to connect to the tracker and start seeding. The ip address returned by the 'host' bash command will be announced to the tracker. The server will not stop seeding until the stop_seeding task is called. You must specify a valid 'tag' argument (which identifies the .torrent in /tmp to use)
  DESC
  task :start_seeding, :roles => :seeder do
    
		# CHECK
		check

		# INFO
		puts "::::::::::::::::: Start seeding"
		puts ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"

		# start seeding
    run "SCREENRC=/dev/null SYSSCREENRC=/dev/null screen -dms 'seeder-#{tag}' python #{murder_path}/murder_client.py seeder '#{filename}.torrent' '#{filename}' `/sbin/ifconfig $1 | grep 'inet addr:10' | awk -F: '{print $2}' | awk '{print $1}'`"

  end



  # =============================================================================================================
  # @author: lha
	# STEP 6
	# occur in the Peers
	# START PEERING
  # modify the original code
  # don't use host $HOSTNAME to capture the IP address of the peers anymore
  # ============================================================================================================= 
  desc <<-DESC
  Instructs all the peer servers to connect to the tracker and start download and spreading pieces and files amongst themselves. You must specify a valid 'tag' argument. Once the download is complete on a server, that server will fork the download process and seed for 30 seconds while returning control to Capistrano. Cap will then extract the files to the passed in 'destination_path' argument to destination_path/TAG/*. To not create this tag named directory, pass in the 'no_tag_directory=1' argument. If the directory is empty, this command will fail. To clean it, pass in the 'unsafe_please_delete=1' argument. The compressed tgz in /tmp is never removed. When this task completes, all files have been transferred and moved into the requested directory.
  DESC
  task :start_peering, :roles => :peer do
    # CHECK
		check
        
		# INFO
		puts "::::::::::::::::: Start peering"
		puts ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"

		# get the .torrent file from Murder Server
		puts "::::::::::::::::: Transfering the .torrent file from Murder Server to all Peers "
		upload("#{filename}.torrent", "#{filename}.torrent")

		# start peering
		puts "::::::::::::::::: Peering"
    run "python #{murder_path}/murder_client.py peer '#{filename}.torrent' '#{filename}' `/sbin/ifconfig $1 | grep 'inet addr:10' | awk -F: '{print $2}' | awk '{print $1}'`"

		# untar into the distribution folder
		puts "::::::::::::::::: Untaring the compressed source file into the Distribution folder"
		run "tar -xzf #{filename} --strip-components=1 -C #{distribution_path}"

  end


	# =============================================================================================================
  # @author: lha
	# STEP 7
  # occur in the Seeder/Tracker/Peer
	# CLEAN TEMP FILES
  # ============================================================================================================= 
	desc 'Clean all temporary files'
	task :clean_temp_files, :roles => [:tracker, :seeder, :peer] do
    # CHECK
		check
		
		# INFO
		puts "::::::::::::::::: Cleaning up temp files in seeder/tracker/peer"
		run "rm -rf #{temp_path}/* || exit 0"
  
		puts "::::::::::::::::: Cleaning up temp files in Murder Server"
		system "rm -rf #{temp_path}/* || exit 0"
	end


  ###
  

  # =============================================================================================================
  # @author: lha
  # each distribution needs a tag
  # =============================================================================================================
  def check
		if (temp_path=="")
			puts "The temporary directory has to be set!!!"
			exit(1)
  	end

		if (tag=="")
			puts "The default tag has to be set!!!"
			exit(1)
  	end

		if (tag.include?("/"))
      puts "The tag cannot contain a / character!!!"
      exit(1)
    end

		if (murder_path=="")
			puts "The murder directory has to be set!!!"
			exit(1)
  	end

		if (distribution_path=="")
			puts "The distribution directory has to be set!!!"
			exit(1)
  	end

		# filename specified where the compressed file is
		set :filename, "#{temp_path}/#{tag}.tar.gz"
  end
end
