module.exports = {
  apps: [{
    name: 'jusoor-backend',
    script: './server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    
    // Environment variables
    env: {
      NODE_ENV: 'development',
      PORT: 5000
    },
    
    env_production: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    
    // Error handling
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    
    // Restart delay
    restart_delay: 4000,
    
    // Max restarts within timeframe
    max_restarts: 10,
    min_uptime: '10s',
    
    // Auto restart on certain exit codes
    kill_timeout: 3000,
    listen_timeout: 3000,
    
    // Exponential backoff restart delay
    exp_backoff_restart_delay: 100
  }]
};
