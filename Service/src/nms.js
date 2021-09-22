const NodeMediaServer = require('node-media-server');

const config = {
  rtmp: {
    port: 1935,
    chunk_size: 60000,
    gop_cache: true,
    ping: 30,
    ping_timeout: 60
  },
  http: {
    port: 8000,
    mediaroot: './media',
    allow_origin: '*'
  },
  trans: {
    ffmpeg: '/opt/homebrew/bin/ffmpeg',
    tasks: [
      {
        app: 'live',
        hls: true,
        hlsFlags: '[hls_time=6:hls_playlist_type=vod:http_seekable=1]',
        dash: true,
        dashFlags: '[f=dash:window_size=3:extra_window_size=5]'
      }
    ]
  }
};

var nms = new NodeMediaServer(config);
nms.run();
