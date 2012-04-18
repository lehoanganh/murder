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
  #	STEP 2 
	#	occur in the Tracker/Seeder
  # START THE TRACKER
  # =============================================================================================================
  desc "Starts the Bittorrent tracker (essentially a mini-web-server) listening on port 8998."
  task :start_tracker, :roles => :tracker do
		
		# INFO
		puts "::::::::::::::::: Starting the Tracker Server"
		puts ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
		
		run("SCREENRC=/dev/null SYSSCREENRC=/dev/null screen -dms murder_tracker python #{murder_path}/murder_tracker.py && sleep 0.2", :pty => true)
  end



	# =============================================================================================================
  # @author: lha
	# STEP 8
  # occur in Seeder/Tracker/Peer
	# STOP ALL MURDER RELATED PROCESSES
  # =============================================================================================================
  desc "Stop all Murder related processes"
  task :stop_all, :roles => [:tracker, :seeder, :peer] do

		# INFO
		puts "::::::::::::::::: Stopping all Murder related processes"
		puts ":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"

		run "pkill -f 'murder'"
  
	end
end
