
var noble = require('noble');
var async = require('async');

var serviceUUID = uuid('E20A39F4-73F5-4BC4-A12F-17D1AD07A961');
var attitudeCharacteristic = uuid('08590F7E-DB05-467E-8757-72F6FAEB13D4');

var services = [serviceUUID];
var characteristics = [attitudeCharacteristic];

module.exports = initCentral;

function initCentral(messageCb) {
  noble.on('stateChange', function(state) {
    console.log('state change ' + state);
    if (state === 'poweredOn') {
      console.log('powered on');
      noble.startScanning(services);
    } else {
      console.log('powered off');
      noble.stopScanning();
    }
  });

  noble.on('discover', function(peripheral) {
    console.log('Peripheral discovered:' + peripheral.uuid);
    console.log('Advertised services:', JSON.stringify(peripheral.advertisement.serviceUuids));
    explore(peripheral, messageCb);
  });
}

function explore(peripheral, messageCb) {
  console.log('services and characteristics:');

  peripheral.on('disconnect', function() {
    console.log('disconnect');
    process.exit(0);
  });

  peripheral.connect(function(error) {
    peripheral.discoverServices(services, function(error, services) {
      if (services.length == 0) {
        console.log('no service found');
        return;
      }
      console.log('yay found service');
      var service = services[0];
      service.discoverCharacteristics(characteristics, function(err, characteristics) {
        console.log('characteristics:');
        characteristics.forEach(function(each) {
          console.log(each.uuid);
        })
        var characteristic = characteristics[0];
        read(peripheral, characteristic, messageCb);
      })
    });
  });
}

function read(peripheral, characteristic, messageCb) {
  var i = 1;
  characteristic.on('read', function(data, isNotification) {
    var pitch = data.readFloatLE(0);
    var roll = data.readFloatLE(4);
    var yaw = data.readFloatLE(8);
    messageCb(null, {pitch: pitch, roll: roll, yaw: yaw});
  })
  characteristic.on('notify', function(data) {
    console.log('notify', data);
  })
  characteristic.notify(true);
  process.on('SIGINT', function() {
    characteristic.notify(false, function() {
      peripheral.disconnect();
    })
  });
}

function uuid(coreBluetoothUUID) {
  return coreBluetoothUUID.toLowerCase().replace(/-/g, '');
}
