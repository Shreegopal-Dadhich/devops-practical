const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({ service: 'gainserv-devops-practical', status: 'ok' });
});

app.get('/healthz', (req, res) => {
  res.status(200).send('ok');
});

app.get('/compute', (req, res) => {
  const iterations = parseInt(req.query.iterations, 10) || 5000000;
  let total = 0;
  for (let i = 0; i < iterations; i++) {
    total += Math.sqrt(i);
  }
  res.json({ iterations, result: total });
});

app.listen(PORT, () => {
  console.log(`listening on ${PORT}`);
});
