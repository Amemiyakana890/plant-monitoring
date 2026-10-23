import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

function dispatch(
  handler,
  { uid, params = {}, body = {}, query = {}, headers = {}, deviceOwnerUid },
) {
  return new Promise((resolve, reject) => {
    const req = { user: { uid }, params, body, query, headers, deviceOwnerUid };
    const res = {
      statusCode: 200,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(responseBody) {
        resolve({ status: this.statusCode, body: responseBody, req });
      },
      end() {
        resolve({ status: this.statusCode, body: undefined, req });
      },
    };

    try {
      const result = handler(req, res, () =>
        resolve({ status: res.statusCode, body: undefined, req }),
      );
      if (result && typeof result.then === 'function') result.catch(reject);
    } catch (error) {
      reject(error);
    }
  });
}

test('legacy data, API operations, settings, notifications, and sensor keys are user-scoped', async (t) => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'plant-ownership-'));
  const dbPath = path.join(directory, 'legacy.db');
  const legacyDb = new DatabaseSync(dbPath);
  legacyDb.exec(`
    CREATE TABLE devices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_name TEXT NOT NULL,
      mac_address TEXT NOT NULL UNIQUE,
      firmware_version TEXT,
      battery_level INTEGER,
      status TEXT NOT NULL DEFAULT 'connected',
      paired_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );
    CREATE TABLE plants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id INTEGER,
      name TEXT NOT NULL,
      species TEXT,
      image TEXT,
      status TEXT NOT NULL DEFAULT 'healthy',
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    );
    INSERT INTO devices (id, device_name, mac_address)
      VALUES (1, 'legacy sensor', 'AA:BB:CC:DD:EE:01');
    INSERT INTO plants (id, device_id, name)
      VALUES (1, 1, 'legacy plant');
  `);
  legacyDb.close();

  process.env.DB_PATH = dbPath;
  process.env.LEGACY_DATA_OWNER_UID = 'legacy-owner';
  process.env.DEVICE_API_KEY = 'legacy-device-key';
  const { default: db } = await import('../database/db.js');
  t.after(async () => {
    db.close();
    await rm(directory, { recursive: true, force: true });
  });

  const plantsController = await import('../controllers/plantsController.js');
  const devicesController = await import('../controllers/devicesController.js');
  const historyController = await import('../controllers/historyController.js');
  const notificationsController = await import('../controllers/notificationsController.js');
  const settingsController = await import('../controllers/settingsController.js');
  const { requireDeviceAuth } = await import('../middleware/require_device_auth.js');
  const { receiveSensorData } = await import('../controllers/sensorController.js');

  const legacyPlants = await dispatch(plantsController.listPlants, {
    uid: 'legacy-owner',
  });
  assert.equal(legacyPlants.body.length, 1);
  assert.equal(legacyPlants.body[0].name, 'legacy plant');

  const newPlants = await dispatch(plantsController.listPlants, { uid: 'new-owner' });
  assert.deepEqual(newPlants.body, []);
  const deniedLegacyDevice = await dispatch(devicesController.getDevice, {
    uid: 'new-owner',
    params: { id: 1 },
  });
  assert.equal(deniedLegacyDevice.status, 404);
  const deniedLegacyUnpair = await dispatch(devicesController.unpairDevice, {
    uid: 'new-owner',
    params: { id: 1 },
  });
  assert.equal(deniedLegacyUnpair.status, 404);
  const deniedLegacyPlant = await dispatch(plantsController.getPlant, {
    uid: 'new-owner',
    params: { id: 1 },
  });
  assert.equal(deniedLegacyPlant.status, 404);

  const pairedDevice = await dispatch(devicesController.pairDevice, {
    uid: 'new-owner',
    body: {
      device_name: 'new sensor',
      mac_address: 'AA:BB:CC:DD:EE:02',
    },
  });
  assert.equal(pairedDevice.status, 201);
  assert.equal(typeof pairedDevice.body.device_api_key, 'string');
  assert.equal(pairedDevice.body.device_api_key.length, 64);

  const newDeviceList = await dispatch(devicesController.listDevices, {
    uid: 'new-owner',
  });
  assert.equal(newDeviceList.body.length, 1);
  assert.equal('device_api_key' in newDeviceList.body[0], false);
  const legacyDeviceList = await dispatch(devicesController.listDevices, {
    uid: 'legacy-owner',
  });
  assert.equal(legacyDeviceList.body.length, 1);

  const newPlant = await dispatch(plantsController.createPlant, {
    uid: 'new-owner',
    body: {
      name: 'new plant',
      device_id: pairedDevice.body.id,
    },
  });
  assert.equal(newPlant.status, 201);
  assert.equal(newPlant.body.name, 'new plant');
  assert.equal((await dispatch(plantsController.listPlants, { uid: 'legacy-owner' })).body.length, 1);
  assert.equal((await dispatch(plantsController.listPlants, { uid: 'new-owner' })).body.length, 1);

  const deniedHistory = await dispatch(historyController.getHistory, {
    uid: 'new-owner',
    params: { plantId: 1 },
  });
  assert.equal(deniedHistory.status, 404);

  const legacySettings = await dispatch(settingsController.getNotificationSettings, {
    uid: 'legacy-owner',
  });
  const newSettings = await dispatch(settingsController.getNotificationSettings, {
    uid: 'new-owner',
  });
  assert.equal(legacySettings.body.sound_enabled, true);
  assert.equal(newSettings.body.sound_enabled, true);
  const updatedNewSettings = await dispatch(settingsController.updateNotificationSettings, {
    uid: 'new-owner',
    body: { sound_enabled: false },
  });
  assert.equal(updatedNewSettings.body.sound_enabled, false);
  assert.equal(
    (await dispatch(settingsController.getNotificationSettings, { uid: 'legacy-owner' })).body
      .sound_enabled,
    true,
  );

  db.prepare(`INSERT INTO notifications (plant_id, message) VALUES (?, ?)`).run(1, 'legacy alert');
  db.prepare(`INSERT INTO notifications (plant_id, message) VALUES (?, ?)`).run(
    newPlant.body.id,
    'new alert',
  );
  assert.equal(
    (await dispatch(notificationsController.listNotifications, { uid: 'legacy-owner' })).body
      .length,
    1,
  );
  assert.equal(
    (await dispatch(notificationsController.listNotifications, { uid: 'new-owner' })).body
      .length,
    1,
  );
  assert.equal(
    (
      await dispatch(notificationsController.markNotificationRead, {
        uid: 'new-owner',
        params: { id: 1 },
        body: { is_read: true },
      })
    ).status,
    404,
  );

  const authenticatedLegacyDevice = await dispatch(requireDeviceAuth, {
    body: { device_id: 1 },
    headers: { 'x-device-api-key': 'legacy-device-key' },
  });
  assert.equal(authenticatedLegacyDevice.req.deviceOwnerUid, 'legacy-owner');
  const rejectedCrossAccountKey = await dispatch(requireDeviceAuth, {
    body: { device_id: 1 },
    headers: { 'x-device-api-key': pairedDevice.body.device_api_key },
  });
  assert.equal(rejectedCrossAccountKey.status, 401);

  const sensorResult = await dispatch(receiveSensorData, {
    body: {
      device_id: pairedDevice.body.id,
      temperature: 25,
      humidity: 55,
      soil: 50,
      illuminance: 300,
    },
    deviceOwnerUid: 'new-owner',
  });
  assert.equal(sensorResult.status, 201);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM sensor_logs WHERE plant_id = ?')
    .get(newPlant.body.id).count, 1);

  assert.equal(
    createHash('sha256').update('legacy-device-key').digest('hex'),
    db.prepare('SELECT api_key_hash FROM devices WHERE id = 1').get().api_key_hash,
  );
});
