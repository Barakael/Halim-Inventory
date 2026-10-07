module.exports = {
  apps: [
    {
      name: "haslim-inventory",
      // Production host path (do not deploy until moving phase). Local: run from frontend/
      cwd: __dirname,
      script: "server.js",
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      watch: false,
      max_memory_restart: "768M",
      restart_delay: 5000,
      env: {
        NODE_ENV: "production",
        PORT: 40000,
      },
    },
  ],
};
