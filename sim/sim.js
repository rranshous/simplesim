const SOCKET_PATH = '/tmp/sim.sock';

const net      = require('net'),
      readline = require('readline'),
      msgpack  = require('msgpack'),
      Matter   = require('matter-js'),
      uuid     = require('uuid/v1'),
      fs       = require('fs');

var port = 5000,
    unixsocket = SOCKET_PATH;

var Engine = Matter.Engine,
    World  = Matter.World,
    Events = Matter.Events,
    Bodies = Matter.Bodies,
    Body   = Matter.Body;

var upcase = function(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}


function Sim(engine, world) {
  this.engine = engine;
  this.world  = world;
  this.rate   = 1000 / 60;
  this.bodies = {};

  this.tick = function() { Engine.update(this.engine, 1000 / 60); };

  this.addSquare = function(opts) {
    var width    = opts.width,
        position = opts.position,
        static   = opts.static;

    var body = Bodies.rectangle(position.x, position.y, width, width, { isStatic: static })

    World.add(world, [body]);
    this.trackBody(body);
  };

  this.push = function(opts) {
    var body      = findBody(opts.body_uuid),
        direction = opts.direction,
        force     = Vector.create(direction),
        position  = force;
    Body.applyForce(body, force, force);
    return true
  };

  this.findBody = function(body_uuid) {
    return this.bodies[body_uuid];
  };

  this.trackBody = function(body) {
    var body_uuid = uuid();
    this.bodies[body_uuid] = body;
    body.uuid = body_uuid;
    return body_uuid;
  };
};

function Commander(sim) {
  this.sim = sim;

  this.tick = function(opts) {
    this.sim.tick();
  };

  this.add = function(opts) {
    var methodName = `add${upcase(opts.shape)}`
    console.log("shape method:", methodName);
    var body_uuid = this.sim[methodName]({
      width:    opts.size,
      static:   false,
      position: { x: opts.position.x, y: opts.position.y },
    });
    return this.detail(body_uuid);
  }

  this.push = function(opts) {
    this.sim.push({
      body_uuid: opts.body_uuid,
      direction: opts.direction,
      force:     10
    })
    return this.detail(body_uuid);
  }

  this.detail = function(body_uuid) {
    return { body_uuid: body_uuid };
  }
};


var engine = Engine.create(),
    world  = engine.world;

Events.on(world, 'afterAdd', function(event) {
  console.log('added to world:', event.object);
});

Events.on(world, 'collisionStart', function(event) {
  console.log('collion start', event.pairs);
});


var sim       = new Sim(engine, world),
    commander = new Commander(sim);

function handle(socket) {
  const rl = readline.createInterface({ input: socket });
  rl.on('line', function(line) {
    console.log('got line', line);
    var data = msgpack.parse(line);
    commander[data.message](data);
  });
};

var server = net.createServer(handle);
server.listen(unixsocket);

server.on('err', function(err) {
  console.log(err);
  server.close(function() {
    console.log("shutting down the server!");
    fs.unlink(SOCKET_PATH);
  });
});

commander.add({
  width:    10,
  position: { x: 10, y: 10 },
  shape:    'square'
});
