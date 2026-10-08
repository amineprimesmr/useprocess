const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const endpoints = require('../lib/clipperRetired.js');

async function serve(t) {
  const app = express();
  app.use(express.json());
  for (const [name, handler] of Object.entries(endpoints)) app.all(`/${name}`, handler);
  const server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  t.after(() => new Promise(resolve => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

test('retired clipper entry points refuse registrations, logins, attribution and portal access', async t => {
  const base = await serve(t);
  for (const name of Object.keys(endpoints).filter(n => !['affiliateResolveCode', 'affiliateRevenueCatWebhook'].includes(n))) {
    const res = await fetch(`${base}/${name}`, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: '{}' });
    assert.equal(res.status, 410, name);
    assert.equal((await res.json()).error, 'CLIPPER_PROGRAM_RETIRED');
  }
});

test('legacy webhook is acknowledged without creating commissions', async t => {
  const base = await serve(t);
  const res = await fetch(`${base}/affiliateRevenueCatWebhook`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({event:{type:'INITIAL_PURCHASE',app_user_id:'test-user'}})});
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {ok:true, skipped:'CLIPPER_PROGRAM_RETIRED'});
});

test('referral compatibility resolver rejects unsupported requests before any database lookup', async t => {
  const base = await serve(t);
  assert.equal((await fetch(`${base}/affiliateResolveCode`)).status, 405);
  for (const code of ['', 'LONGCREATORCODE', '../bad']) {
    const res = await fetch(`${base}/affiliateResolveCode`, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({code})});
    assert.equal(res.status, 404);
  }
});
