const app = require('express')();
const fs = require('fs');
const hls = require('hls-server');

app.get('/', (req, res) => {
  return res.status(200).sendFile(`${__dirname}/index.html`);
});

app.get('/api/get_video', (req, res) => {
  const sample = { 
    url: '/videos/ayc.m3u8',
    sampleUrl: '/videos/ayc-sample.m3u8',
    totalLength: 58
  };

  return res.status(200).json(sample)
});

const server = app.listen(8000);

new hls(server, {
  provider: {
    exists: (req, cb) => {
      const ext = req.url.split('.').pop();

      if (ext !== 'm3u8' && ext !== 'ts') {
        return cb(null, true);
      }

      fs.access(__dirname + req.url, fs.constants.F_OK, function (err) {
        if (err) {
          console.log('File not exist');
          return cb(null, false);
        }
        cb(null, true);
      });
    },
    getManifestStream: (req, cb) => {
      const stream = fs.createReadStream(__dirname + req.url);
      cb(null, stream);
    },
    getSegmentStream: (req, cb) => {
      const stream = fs.createReadStream(__dirname + req.url);
      cb(null, stream);
    }
  }
});
