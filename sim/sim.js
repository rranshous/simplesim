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
    Engine.update(this.engine, opts.step_ms);
    return true
  };

  this.addRectangle = function(opts) {
    var width    = opts.width,
        height   = opts.height,
        position = opts.position,
        static   = opts.static;

    var body = Bodies.rectangle(
      position.x, position.y, width, height, { isStatic: static }
    )

    body.width = width;
    body.height = height;
    body.shape = 'rectangle';

    World.add(this.world, [body]);
    return this.trackBody(body);
  };

  this.addSquare = function(opts) {
    var width    = opts.width,
        position = opts.position,
        static   = opts.static;

    var body = Bodies.rectangle(
      position.x, position.y, width, width, { isStatic: static }
    )

    body.width = width;
    body.height = width;
    body.shape = 'square';

    World.add(this.world, [body]);
    return this.trackBody(body);
  };

  this.push = function(opts) {
    var body      = this.findBody(opts.body_uuid),
        direction = opts.direction,
        force     = Vector.create(direction),
        position  = force;
    Body.applyForce(body, force, force);
    return true
  };

  this.detail = function(opts) {
    var body = this.findBody(opts.body_uuid);
    return {
      position: { x: body.position.x, y: body.position.y },
      rotation: body.angle,
      body_uuid: body.uuid,
      width: body.width,
      height: body.height,
      shape: body.shape,
      static: body.isStatic
    };
  };

  this.setGravity = function(opts) {
    if(typeof opts.x !== "undefined") {
      this.world.gravity.x = opts.x
    }
    if(typeof opts.y !== "undefined") {
      this.world.gravity.y = opts.y
    }
    return {
      x: this.world.gravity.x,
      y: this.world.gravity.y
    }
  };

  this.findBody = function(body_uuid) {
    return this.bodies[body_uuid];
  };

  this.listBodies = function() {
    var bodies = Object.keys(this.bodies);
    return bodies;
  };

  this.trackBody = function(body) {
    var body_uuid = uuid();
    body.uuid = body_uuid;
    this.bodies[body_uuid] = body;
    return body_uuid;
  };
};

function Commander(sim) {
  this.sim = sim;

  this.tick = function(opts) {
    this.sim.tick(opts);
    return { };
  };

  this.add_square = function(opts) {
    var body_uuid = this.sim.addSquare({
      width:    opts.size,
      static:   opts.static,
      position: { x: opts.position.x, y: opts.position.y },
    });
    return { body_uuid: body_uuid };
  };

  this.add_rectangle = function(opts) {
    var body_uuid = this.sim.addRectangle({
      width:    opts.width,
      height:   opts.height,
      static:   opts.static,
      position: { x: opts.position.x, y: opts.position.y },
    });
    return { body_uuid: body_uuid };
  };

  this.add = function(opts) {
    opts.static = opts.static || false;
    return this[`add_${opts.shape}`](opts);
  };

  this.push = function(opts) {
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
    return this.sim.detail({ body_uuid: opts.body_uuid });
  };

  this.list_details = function(opts) {
    var obj = this;
    return this.list_bodies().map(function(body_details) {
      return obj.detail(body_details);
    });
  };

  this.list_bodies = function(opts) {
    return this.sim.listBodies().map(function(uuid) {
      return { body_uuid: uuid }
    });
  }
};


var engine = Engine.create(),
    world  = engine.world;

Events.on(world, 'afterAdd', function(event) {
  //console.log('added to world:', event.object);
});

Events.on(world, 'collisionStart', function(event) {
  console.log('collion start', event.pairs);
});


var sim       = new Sim(engine, world),
    commander = new Commander(sim);

function handleMessage(message) {
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

fs.unlinkSync(SOCKET_PATH);
var server = net.createServer(handle);
server.listen(unixsocket);

server.on('err', function(err) {
  console.log(err);
  server.close(function() {
    console.log("shutting down the server!");
    fs.unlink(SOCKET_PATH);
  });
});

console.log("starting");

//setInterval(function() {
//  Engine.update(engine, 1000 / 60);
//}, 1000 / 60);
