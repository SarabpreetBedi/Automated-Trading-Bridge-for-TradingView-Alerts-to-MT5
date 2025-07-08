// sample/sign.js
// Simple function to prepare alert JSON (expand with signing if needed)

function prepareAlert(cmd, symbol, lot, sl, tp) {
  return JSON.stringify({
    cmd,
    symbol,
    lot,
    sl,
    tp,
    time: new Date().toISOString()
  });
}

if (require.main === module) {
  const alert = prepareAlert("BUY", "EURUSD", 0.1, 20, 40);
  console.log(alert);
}

module.exports = { prepareAlert };
