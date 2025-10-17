const puppeteer = require('puppeteer');
const url = process.argv[2] || 'http://localhost:3000/d/chaoscanary-overview/chaos-canary-overview';
const out = process.argv[3] || 'grafana-dashboard.png';
(async () => {
  const browser = await puppeteer.launch({args: ['--no-sandbox', '--disable-setuid-sandbox']});
  const page = await browser.newPage();
  await page.setViewport({width: 1200, height: 800});
  await page.goto(url, {waitUntil: 'networkidle2'});
  // If Grafana asks for login, default creds are admin/admin
  try {
    await page.waitForSelector('.login-container', {timeout: 2000});
    await page.type('input[name="user"]', 'admin');
    await page.type('input[name="password"]', 'admin');
    await page.click('button[type="submit"]');
    await page.waitForNavigation({waitUntil: 'networkidle2'});
  } catch (e) {
    // login not required
  }
  await page.screenshot({path: out});
  await browser.close();
  console.log('Saved', out);
})();
