@dir = Dir::pwd

worker_processes 2
working_directory @dir

listen 3131

pid "#{@dir}/tmp/unicorn.pid"

stderr_path "#{@dir}/log/error.log"
stdout_path "#{@dir}/log/unicorn.log"
