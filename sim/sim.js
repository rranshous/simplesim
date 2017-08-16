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
    Vector = Matter.Vector,
    Bodies = Matter.Bodies,
    Body   = Matter.Body;

var upcase = function(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}


function Sim(engine, world) {
  this.engine = engine;
  this.world  = world;
  this.bodies = {};

  this.tick = function(opts) {
    console.log("sim tick:", opts.step_ms);
    Engine.update(this.engine, opts.step_ms);
    return true
  };

  this.addSquare = function(opts) {
    console.log("sim add square");
    var width    = opts.width,
        position = opts.position,
        static   = opts.static;

    console.log("width:",width);

    var body = Bodies.rectangle(
      position.x, position.y, width, width, { isStatic: static }
    )

    World.add(this.world, [body]);
    return this.trackBody(body);
  };

  this.push = function(opts) {
    console.log("sim push");
    var body      = this.findBody(opts.body_uuid),
        direction = opts.direction,
        force     = Vector.create(direction),
        position  = force;
    Body.applyForce(body, force, force);
    return true
  };

  this.detail = function(opts) {
    var body = this.findBody(opts.body_uuid);
    console.log("sim detail:",body.position.x,body.position.y);
    return {
      position: { x: body.position.x, y: body.position.y },
      rotation: body.angle,
      body_uuid: body.uuid
    };
  };

  this.setGravity = function(opts) {
    console.log("set gravity:", opts.x, opts.y);
    if(typeof opts.x !== "undefined") {
      console.log("new x", opts.x)
      this.world.gravity.x = opts.x
    }
    if(typeof opts.y !== "undefined") {
      console.log("new y", opts.y)
      this.world.gravity.y = opts.y
    }
    return {
      x: this.world.gravity.x,
      y: this.world.gravity.y
    }
  };

  this.findBody = function(body_uuid) {
    console.log("find body", body_uuid)
    return this.bodies[body_uuid];
  };

  this.trackBody = function(body) {
    console.log("track body");
    var body_uuid = uuid();
    body.uuid = body_uuid;
    this.bodies[body_uuid] = body;
    return body_uuid;
  };
};

function Commander(sim) {
  this.sim = sim;

  this.tick = function(opts) {
    console.log("commander tick", opts);
    this.sim.tick(opts);
    return { };
  };

  this.add = function(opts) {
    var methodName = `add${upcase(opts.shape)}`;
    console.log("shape method:", opts);
    var body_uuid = this.sim[methodName]({
      width:    opts.size,
      static:   false,
      position: { x: opts.position.x, y: opts.position.y },
    });
    return { body_uuid: body_uuid };
  };

  this.push = function(opts) {
    console.log("commander push", opts);
    this.sim.push({
      body_uuid: opts.body_uuid,
      direction: opts.direction,
      force:     10
    })
    return { body_uuid: opts.body_uuid };
  };

  this.set_gravity = function(opts) {
    return this.sim.setGravity({x: opts.x, y: opts.y});
  };

  this.detail = function(opts) {
    console.log("commander detail", opts);
    return this.sim.detail({ body_uuid: opts.body_uuid });
  };
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

function handleMessage(message) {
  console.log('message', message);
  return commander[message.message](message);
};

function handle(socket) {
  var rl = readline.createInterface({ input: socket });
  rl.on('line', function(line) {
    var inputData = JSON.parse(line);
    var response_data = handleMessage(inputData);
    response_data.request_id = inputData.request_id
    // blocking write?
    socket.write(JSON.stringify(response_data));
    socket.write("\n");
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

//setInterval(function() {
//  Engine.update(engine, 1000 / 60);
//}, 1000 / 60);
